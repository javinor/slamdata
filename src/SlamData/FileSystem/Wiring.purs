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

module SlamData.FileSystem.Wiring
  ( Wiring
  , makeWiring
  ) where

import SlamData.Prelude


import Control.Monad.Aff.Bus as Bus
import Control.Monad.Aff.Free (class Affable, fromAff)

import SlamData.Effects (SlamDataEffects)
import SlamData.GlobalError as GE
import SlamData.Quasar.Auth.Authentication as Auth
import SlamData.SignIn.Bus (SignInBus)

type Wiring =
  { globalError ∷ Bus.BusRW GE.GlobalError
  , requestNewIdTokenBus ∷ Auth.RequestIdTokenBus
  , signInBus ∷ SignInBus
  }

makeWiring
  ∷ ∀ m
  . (Affable SlamDataEffects m)
  ⇒ m Wiring
makeWiring = fromAff do
  globalError ← Bus.make
  requestNewIdTokenBus ← Auth.authentication
  signInBus ← Bus.make
  let
    wiring =
      { globalError
      , requestNewIdTokenBus
      , signInBus
      }
  pure wiring