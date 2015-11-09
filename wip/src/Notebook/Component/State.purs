{-
Copyright 2015 SlamData, Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-}

module Notebook.Component.State
  ( NotebookState()
  , CellDef()
  , initialNotebook
  , addCell
  , removeCells
  , findRoot
  , findParent
  , findChildren
  , findDescendants
  , getCurrentValue
  ) where

import Prelude

import Data.BrowserFeatures (BrowserFeatures())
import Data.Foldable (foldMap)
import Data.List (List(), snoc, filter)
import Data.Map as M
import Data.Maybe (Maybe(..), maybe)
import Data.Monoid (mempty)
import Data.Set as S
import Data.These (These(..))
import Data.Tuple (Tuple(..), fst)
import Data.Visibility (Visibility(..))

import Halogen

import Notebook.AccessType (AccessType(..))
import Notebook.Cell.Ace.Component (aceComponent)
import Notebook.Cell.CellId (CellId(..))
import Notebook.Cell.CellType (CellType(..))
import Notebook.Cell.Component
import Notebook.Cell.Markdown.Component (markdownComponent)
import Notebook.Cell.Markdown.Eval (markdownEval)
import Notebook.Cell.Port (Port())
import Notebook.CellSlot (CellSlot(..))
import Notebook.Common (Slam())

-- | The notebook state.
-- |
-- | - `fresh` is a counter used to generate `CellId` values.
-- | - `cells` is the list of cells currently in the notebook.
-- | - `dependencies` is a map of the edges in the dependency tree, where each
-- |   `key/value` pair represents a `child/parent` relation.
-- | - `values` is a cache of the most values that were returned when a cell
-- |   was run.
-- | - `activeCellId` is the `CellId` for the currently focused cell.
-- | - `editable` determines whether the notebook is being edited or displayed
-- |   in read-only mode.
-- | - `name` is the current notebook name. When the value is `This` is has yet
-- |   to be saved. When the value is `That` it has been saved. When the value
-- |   is `Both` a new name has been entered but it has not yet been saved with
-- |   the new name.
type NotebookState =
  { fresh :: Int
  , accessType :: AccessType
  , cells :: List CellDef
  , dependencies :: M.Map CellId CellId
  , values :: M.Map CellId Port
  , activeCellId :: Maybe CellId
  , editable :: Boolean
  , name :: These String String
  , isAddingCell :: Boolean
  , browserFeatures :: BrowserFeatures
  }

type CellDef =
  { id :: CellId
  , ctor :: SlotConstructor CellStateP CellQueryP Slam CellSlot
  }

initialNotebook :: BrowserFeatures -> NotebookState
initialNotebook fs =
  { fresh: 0
  , accessType: Editable
  , cells: mempty
  , dependencies: M.empty
  , values: M.empty
  , activeCellId: Nothing
  , editable: true
  , name: This Config.newNotebookName
  , isAddingCell: false
  , browserFeatures: fs
  }

-- | Adds a new cell to the notebook.
-- |
-- | Takes the current notebook state, the type of cell to add, and an optional
-- | parent cell ID.
addCell :: CellType -> Maybe CellId -> NotebookState -> NotebookState
addCell cellType parent st =
  let editorId = CellId st.fresh
      resultsId = CellId $ st.fresh + 1
      editor = case cellType of
        _ -> { component: aceComponent Markdown markdownEval "ace/mode/markdown"
             , initialState: installedState (initEditorCellState st.accessType Visible)
             }
      results = case cellType of
        _ -> { component: markdownComponent resultsId st.browserFeatures
             , initialState: installedState (initResultsCellState st.accessType Visible)
             }
      dependencies = M.insert resultsId editorId st.dependencies
  in st
    { fresh = st.fresh + 2
    , cells = st.cells
        `snoc` { id: editorId, ctor: SlotConstructor (CellSlot editorId) \_ -> editor }
        `snoc` { id: resultsId, ctor: SlotConstructor (CellSlot resultsId) \_ -> results }
    , dependencies = maybe dependencies (flip (M.insert editorId) dependencies) parent
    }

-- | Removes a set of cells from the notebook. Any cells that depend on a cell
-- | in the set of provided cells will also be removed.
-- |
-- | Takes the current notebook state and a set of IDs for the cells to remove.
removeCells :: S.Set CellId -> NotebookState -> NotebookState
removeCells cellIds st = st
    { cells = filter f st.cells
    , dependencies = M.fromList $ filter g $ M.toList st.dependencies
    }
  where
  cellIds' :: S.Set CellId
  cellIds' = cellIds <> foldMap (findDescendants st) cellIds
  f :: CellDef -> Boolean
  f = not <<< flip S.member cellIds' <<< _.id
  g :: Tuple CellId CellId -> Boolean
  g (Tuple kId vId) = not $ S.member kId cellIds' || S.member vId cellIds'

-- | Finds the root in a chain of dependencies starting at the specified cell.
-- | A cell can be its own root if it depends on no other cells.
-- |
-- | Takes the current notebook state and the ID of the cell to start searching
-- | from.
findRoot :: NotebookState -> CellId -> CellId
findRoot st cellId = case findParent st cellId of
  Nothing -> cellId
  Just parentId -> findRoot st parentId

-- | Finds the parent of a cell. If the cell is a root it has no parent, and
-- | the result will be `Nothing`.
-- |
-- | Takes the current notebook state and the ID of the cell to find the
-- | parent of.
findParent :: NotebookState -> CellId -> Maybe CellId
findParent st cellId = M.lookup cellId st.dependencies

-- | Finds the immediate dependencies of a cell.
-- |
-- | Takes the current notebook state and the ID of the cell to find the
-- | children of.
findChildren :: NotebookState -> CellId -> S.Set CellId
findChildren st parentId = S.fromList $ map fst $ filter f $ M.toList st.dependencies
  where
  f :: Tuple CellId CellId -> Boolean
  f (Tuple _ cellId) = cellId == parentId

-- | Finds all the dependencies of a cell: the children, children's children,
-- | and so on until the leaves of the tree are reached.
-- |
-- | Takes the current notebook state and the ID of the cell to find the
-- | descendants of.
findDescendants :: NotebookState -> CellId -> S.Set CellId
findDescendants st cellId =
  let children = findChildren st cellId
  in children <> foldMap (findDescendants st) children

-- | Gets the current value stored for the result of a cell's evaluation.
-- |
-- | If the cell has not been evaluated the result will be `Nothing`.
getCurrentValue :: NotebookState -> CellId -> Maybe Port
getCurrentValue st cellId = M.lookup cellId st.values