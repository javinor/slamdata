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

module SlamData.Workspace.AccessType
  ( AccessType(..)
  , parseAccessType
  , printAccessType
  , isEditable
  , isReadOnly
  ) where

import SlamData.Prelude

data AccessType = Editable | ReadOnly

-- | Used in route parsing
parseAccessType ∷ String → Either String AccessType
parseAccessType "view" = Right ReadOnly
parseAccessType "edit" = Right Editable
parseAccessType _ = Left "incorrect accessType string"

-- | Used in route construction
printAccessType ∷ AccessType → String
printAccessType Editable = "edit"
printAccessType ReadOnly = "view"

isEditable ∷ AccessType → Boolean
isEditable Editable = true
isEditable _ = false

isReadOnly ∷ AccessType → Boolean
isReadOnly ReadOnly = true
isReadOnly _ = false

derive instance genericAccessType ∷ Generic AccessType
derive instance eqAccessType ∷ Eq AccessType
derive instance ordAccessType ∷ Ord AccessType

instance showAccessType ∷ Show AccessType where
  show Editable = "Editable"
  show ReadOnly = "ReadOnly"
