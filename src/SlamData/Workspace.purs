{-
Copyright 2016 SlamData, Inc.

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

module SlamData.Workspace (main) where

import SlamData.Prelude

import Data.List as L

import Control.Monad.Aff (Aff, forkAff)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Class (liftEff)

import Ace.Config as AceConfig

import DOM.BrowserFeatures.Detectors (detectBrowserFeatures)

import Halogen (Driver, runUI, parentState)
import Halogen.Util (runHalogenAff, awaitBody)

import SlamData.Config as Config
import SlamData.FileSystem.Routing (parentURL)
import SlamData.Workspace.Action (Action(..), toAccessType)
import SlamData.Workspace.Card.CardId as CID
import SlamData.Workspace.Card.Port as Port
import SlamData.Workspace.Component as Workspace
import SlamData.Workspace.Deck.Component as Deck
import SlamData.Workspace.Deck.DeckId (DeckId)
import SlamData.Effects (SlamDataRawEffects, SlamDataEffects)
import SlamData.Workspace.Routing (Routes(..), routing)
import SlamData.Workspace.StyleLoader as StyleLoader

import Utils.Path as UP

main ∷ Eff SlamDataEffects Unit
main = do
  AceConfig.set AceConfig.basePath (Config.baseUrl ⊕ "js/ace")
  AceConfig.set AceConfig.modePath (Config.baseUrl ⊕ "js/ace")
  AceConfig.set AceConfig.themePath (Config.baseUrl ⊕ "js/ace")
  browserFeatures ← detectBrowserFeatures
  runHalogenAff do
    let
      st = parentState
           $ Workspace.initialState
              { browserFeatures: browserFeatures
              , version: Just "3.0"
              }
    driver ← runUI Workspace.comp st =<< awaitBody
    forkAff (routeSignal driver)
  StyleLoader.loadStyles

routeSignal
  ∷ Driver Workspace.QueryP SlamDataRawEffects
  → Aff SlamDataEffects Unit
routeSignal driver = do
  Tuple _ route ← Routing.matchesAff' UP.decodeURIPath routing
  case route of
    CardRoute res deckIds cardId accessType varMap →
      workspace res deckIds (Load accessType) (Just cardId) varMap
    WorkspaceRoute res deckIds action varMap → workspace res deckIds action Nothing varMap
    ExploreRoute res → explore res

  where

  explore ∷ UP.FilePath → Aff SlamDataEffects Unit
  explore path = do
    fs ← liftEff detectBrowserFeatures
    driver $ Workspace.toDeck $ Deck.ExploreFile fs path
    driver $ Workspace.toWorkspace $ Workspace.SetParentHref
      $ parentURL $ Right path

  workspace
    ∷ UP.DirPath
    → L.List DeckId
    → Action
    → Maybe CID.CardId
    → Port.VarMap
    → Aff SlamDataEffects Unit
  workspace path deckIds action viewing varMap = do
    let name = UP.getNameStr $ Left path
        accessType = toAccessType action
    currentPath ← driver $ Workspace.fromWorkspace Workspace.GetPath
    currentViewing ← driver $ Workspace.fromWorkspace Workspace.GetViewingCard
    currentAccessType ← driver $ Workspace.fromWorkspace Workspace.GetAccessType

    when (currentPath ≠ pure path) do
      features ← liftEff detectBrowserFeatures
      if action ≡ New
        then driver $ Workspace.toWorkspace $ Workspace.Reset features path
        else driver $ Workspace.toWorkspace $ Workspace.Load features path deckIds

    driver $ Workspace.toWorkspace $ Workspace.SetViewingCard viewing
    driver $ Workspace.toWorkspace $ Workspace.SetAccessType accessType
    driver $ Workspace.toDeck $ Deck.SetGlobalVarMap varMap
    driver $ Workspace.toWorkspace $ Workspace.SetParentHref
      $ parentURL $ Left path