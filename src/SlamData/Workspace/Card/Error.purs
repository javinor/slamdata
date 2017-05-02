{-
Copyright 2017 SlamData, Inc.

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

module SlamData.Workspace.Card.Error
  ( module SlamData.Workspace.Card.Error
  , module CCE
  , module CQE
  ) where

import SlamData.Prelude

import Quasar.Error (QError)
import SlamData.GlobalError as GE
import SlamData.Workspace.Card.Cache.Error as CCE
import SlamData.Workspace.Card.Query.Error as CQE
import Utils (hush)

data CardError
  = QuasarError QError
  | StringlyTypedError String
  | CacheCardError CCE.CacheError
  | QueryCardError CQE.QueryError

instance showCardError ∷ Show CardError where
  show = case _ of
    QuasarError err → "(QuasarError " <> show err <> ")"
    StringlyTypedError err → "(StringlyTypedError " <> err <> ")"
    CacheCardError err → "(CacheCardError " <> show err <> ")"
    QueryCardError err → "(QueryCardError " <> show err <> ")"

quasarToCardError ∷ QError → CardError
quasarToCardError = QuasarError

cardToGlobalError ∷ CardError → Maybe GE.GlobalError
cardToGlobalError = case _ of
  QuasarError qError → hush (GE.fromQError qError)
  StringlyTypedError err → Nothing
  CacheCardError err → CCE.cacheToGlobalError err
  QueryCardError err → CQE.queryToGlobalError err

-- TODO(Christoph): use this warn constraint to track down unstructured error messages
-- throw ∷ ∀ m a. MonadThrow CardError m ⇒ Warn "You really don't want to" ⇒ String → m a
throw ∷ ∀ m a. MonadThrow CardError m ⇒ String → m a
throw = throwError ∘ StringlyTypedError

throwCacheError ∷ ∀ m a. MonadThrow CardError m ⇒ CCE.CacheError → m a
throwCacheError = throwError ∘ CacheCardError

throwQueryError ∷ ∀ m a. MonadThrow CardError m ⇒ CQE.QueryError → m a
throwQueryError = throwError ∘ QueryCardError

liftQueryError ∷ ∀ m a. MonadThrow CardError m ⇒ (Either CQE.QueryError a) → m a
liftQueryError x = case lmap QueryCardError x of
  Left err → throwError err
  Right v → pure v

liftQ ∷ ∀ m a. MonadThrow CardError m ⇒ m (Either QError a) → m a
liftQ = flip bind (either (throwError ∘ quasarToCardError) pure)
