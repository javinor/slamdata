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

module SlamData.ActionList.Component.State where

import SlamData.Prelude

import RectanglePacking (Dimensions)
import SlamData.ActionList.Action (Action)

type State a =
  { actions ∷ Array (Action a)
  , previousActions ∷ Array (Action a)
  , activeDrill ∷ Maybe (Action a)
  , filterString ∷ String
  , boundingDimensions ∷ Maybe Dimensions
  }

initialState ∷ ∀ a. Array (Action a) → State a
initialState actions =
  { actions
  , previousActions: mempty
  , activeDrill: Nothing
  , filterString: ""
  , boundingDimensions: Nothing
  }
