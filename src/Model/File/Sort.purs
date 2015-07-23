-- | Sort direction
module Model.File.Sort where

import Prelude
import Data.Either (Either(..))

data Sort = Asc | Desc

-- | revese sort
notSort :: Sort -> Sort
notSort Asc = Desc
notSort _ = Asc

sort2string :: Sort -> String
sort2string Asc = "asc"
sort2string Desc = "desc"

string2sort :: String -> Either String Sort
string2sort "asc" = Right Asc
string2sort "desc" = Right Desc
string2sort _ = Left "incorrect sort string"

instance eqSort :: Eq Sort where
  eq Asc Asc = true
  eq Desc Desc = true
  eq _ _ = false
