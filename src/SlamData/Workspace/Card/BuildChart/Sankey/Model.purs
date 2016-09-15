module SlamData.Workspace.Card.BuildChart.Sankey.Model where

import SlamData.Prelude

import Data.Argonaut (JArray, JCursor, Json, decodeJson, cursorGet, toNumber, toString, (~>), (:=), isNull, jsonNull, (.?), jsonEmptyObject)
import Data.Array as A
import Data.Foldable as F
import Data.Map as M

import SlamData.Workspace.Card.CardType.ChartType (ChartType(..))
import SlamData.Workspace.Card.Chart.Aggregation as Ag

import Test.StrongCheck.Arbitrary (class Arbitrary, arbitrary)
import Test.StrongCheck.Gen as Gen
import Test.Property.ArbJson (runArbJCursor)

type SankeyR =
  { source ∷ JCursor
  , target ∷ JCursor
  , value ∷ JCursor
  , valueAggregation ∷ Ag.Aggregation
  }

type Model = Maybe SankeyR

initialModel ∷ Model
initialModel = Nothing

eqSankeyR ∷ SankeyR → SankeyR → Boolean
eqSankeyR r1 r2 =
  F.and
    [ r1.source ≡ r2.source
    , r1.target ≡ r2.target
    , r1.value ≡ r2.value
    , r1.valueAggregation ≡ r2.valueAggregation
    ]

eqModel ∷ Model → Model → Boolean
eqModel Nothing Nothing = true
eqModel (Just r1) (Just r2) = eqSankeyR r1 r2
eqModel _ _ = false

genModel ∷ Gen.Gen Model
genModel = do
  isNothing ← arbitrary
  if isNothing
    then pure Nothing
    else do
    source ← map runArbJCursor arbitrary
    target ← map runArbJCursor arbitrary
    value ← map runArbJCursor arbitrary
    valueAggregation ← arbitrary
    pure $ Just { source, target, value, valueAggregation }


encode ∷ Model → Json
encode Nothing = jsonNull
encode (Just r) =
  "configType" := "sankey"
  ~> "source" := r.source
  ~> "target" := r.target
  ~> "value" := r.value
  ~> "valueAggregation" := r.valueAggregation
  ~> jsonEmptyObject

decode ∷ Json → String ⊹ Model
decode js
  | isNull js = pure Nothing
  | otherwise = do
    obj ← decodeJson js
    configType ← obj .? "configType"
    unless (configType ≡ "sankey")
      $ throwError "This config is not sankey"
    source ← obj .? "source"
    target ← obj .? "target"
    value ← obj .? "value"
    valueAggregation ← obj .? "valueAggregation"
    pure $ Just { source, target, value, valueAggregation }