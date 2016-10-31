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

module SlamData.Workspace.Eval.Card
  ( EvalMessage(..)
  , EvalResult
  , Cell
  , State
  , Id
  , Transition
  , Coord
  , coordOf
  , module SlamData.Workspace.Card.CardId
  , module SlamData.Workspace.Card.Eval
  , module SlamData.Workspace.Card.Model
  , module SlamData.Workspace.Card.Port
  ) where

import SlamData.Prelude

import Control.Monad.Aff.Bus (BusRW)

import Data.List (List)

import SlamData.Workspace.Card.CardId (CardId(..))
import SlamData.Workspace.Card.Eval (Eval, runEvalCard')
import SlamData.Workspace.Card.Model (Model, modelToEval)
import SlamData.Workspace.Card.Port (Port(..))
import SlamData.Workspace.Eval.Deck as Deck

-- TODO
type State = Unit

data EvalMessage
  = Pending
  | Complete Port
  | StateChange (Maybe State)
  | ModelChange Model

type EvalResult =
  { model ∷ Model
  , input ∷ Maybe Port
  , output ∷ Maybe Port
  , state ∷ Maybe State
  }

type Cell =
  { bus ∷ BusRW EvalMessage
  , next ∷ List Coord
  , value ∷ EvalResult
  }

type Id = CardId

type Transition = Eval

type Coord = Deck.Id × Id

coordOf ∷ Deck.Id × Model → Coord
coordOf = map _.cardId