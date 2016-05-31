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
module SlamData.Workspace.Deck.Slider
  ( startSliding
  , stopSlidingAndSnap
  , updateSliderPosition
  , render
  , containerProperties
  ) where

import SlamData.Prelude

import Data.Array ((..))
import Data.Array as Array
import Data.Int as Int
import Data.Lens ((.~))
import Data.Lens as Lens
import Data.Ord (max, min)
import Data.Tuple as Tuple

import CSS (CSS)

import Halogen as H
import Halogen.HTML.CSS.Indexed (style)
import Halogen.HTML.Events.Handler as HEH
import Halogen.HTML.Events.Indexed as HE
import Halogen.HTML.Events.Types (Event, MouseEvent)
import Halogen.HTML.Indexed as HH
import Halogen.HTML.Properties.Indexed (IProp(), I)
import Halogen.HTML.Properties.Indexed as HP
import Halogen.HTML.Properties.Indexed.ARIA as ARIA

import SlamData.Config as Config
import SlamData.Render.CSS as ClassNames
import SlamData.Workspace.Card.CardId (CardId)
import SlamData.Workspace.Card.CardId as CardId
import SlamData.Workspace.Card.Model as Card
import SlamData.Workspace.Card.Component as CardC
import SlamData.Workspace.Card.Factory (cardTypeComponent)
import SlamData.Workspace.Deck.Common (DeckHTML, DeckDSL)
import SlamData.Workspace.Deck.Component.ChildSlot as ChildSlot
import SlamData.Workspace.Deck.Component.Cycle (DeckComponent)
import SlamData.Workspace.Deck.Component.Query (Query)
import SlamData.Workspace.Deck.Component.Query as DCQ
import SlamData.Workspace.Deck.Component.State (State)
import SlamData.Workspace.Deck.Component.State as DCS
import SlamData.Workspace.Deck.Gripper as Gripper

import Utils.CSS as CSSUtils

render ∷ DeckComponent → State → Boolean → DeckHTML
render comp st visible =
  HH.div
    ([ HP.key "deck-cards"
     , HP.classes [ ClassNames.cardSlider ]
     , HE.onTransitionEnd $ HE.input_ DCQ.StopSliderTransition
     , style do
         cardSliderTransformCSS st.activeCardIndex st.sliderTranslateX
         cardSliderTransitionCSS st.sliderTransition
     ]
     ⊕ (guard (not visible) $> (HP.class_ ClassNames.invisible)))
    $ map (Tuple.uncurry $ renderCard comp st)
    $ Array.zip st.displayCards (0 .. Array.length st.displayCards)

stateStartSliding ∷ Event MouseEvent → Maybe Number → State → State
stateStartSliding mouseEvent cardWidth =
  (DCS._initialSliderX .~ Just mouseEvent.screenX)
    ∘ (DCS._initialSliderCardWidth .~ cardWidth)
    ∘ (DCS._sliderTransition .~ false)
    ∘ (DCS._displayMode .~ DCS.Normal)

startSliding ∷ Event MouseEvent → DeckDSL Unit
startSliding mouseEvent =
  H.gets _.cardElementWidth
    >>= H.modify ∘ stateStartSliding mouseEvent

stateStopSlidingAndSnap ∷ Event MouseEvent → State → State
stateStopSlidingAndSnap mouseEvent =
  stateUpdateSliderPosition mouseEvent
    ⋙ startTransition
    ⋙ snap
    ⋙ stopSliding

stopSlidingAndSnap ∷ Event MouseEvent → DeckDSL Unit
stopSlidingAndSnap = H.modify ∘ stateStopSlidingAndSnap

stateUpdateSliderPosition ∷ Event MouseEvent → State → State
stateUpdateSliderPosition mouseEvent =
  maybe id (Lens.set DCS._sliderTranslateX ∘ translateXCalc mouseEvent.screenX)
    <$> _.initialSliderX
    <*> id

updateSliderPosition ∷ Event MouseEvent → DeckDSL Unit
updateSliderPosition = H.modify ∘ stateUpdateSliderPosition

translateXCalc ∷ Number → Number → Number
translateXCalc eventScreenX initialX =
  eventScreenX - initialX

stopSliding ∷ State → State
stopSliding =
    (DCS._initialSliderX .~ Nothing)
      ∘ (DCS._sliderTranslateX .~ 0.0)

snapActiveCardIndexByTranslationAndCardWidth
  ∷ State
  → Number
  → Int
  → Int
snapActiveCardIndexByTranslationAndCardWidth st cardWidth idx =
  let
    translateX = st.sliderTranslateX
    numberOfCards = Array.length st.displayCards
    halfOffset = (offsetCardSpacing cardWidth) / 2.0
  in
    if translateX <= -1.0 * halfOffset
    then
      min (numberOfCards - 1)
        $ sub idx
        $ one
        + Int.floor ((translateX - halfOffset) / cardWidth)
    else
      if translateX >= halfOffset
      then
        max 0
          $ idx
          + one
          + Int.floor ((-translateX - halfOffset) / cardWidth)
      else idx

offsetCardSpacing ∷ Number → Number
offsetCardSpacing = add $ cardSpacingGridSquares * Config.gridPx

snapActiveCardIndex ∷ State → Int
snapActiveCardIndex st = maybe id snap' st.initialSliderCardWidth st.activeCardIndex
  where
  snap' = snapActiveCardIndexByTranslationAndCardWidth st

snap ∷ State → State
snap st = st { activeCardIndex = snapActiveCardIndex st }

startTransition ∷ State → State
startTransition = DCS._sliderTransition .~ true

willChangeActiveCardWhenDropped ∷ State → Boolean
willChangeActiveCardWhenDropped st=
  st.activeCardIndex ≠ snapActiveCardIndex st

cardPositionCSS ∷ Int → CSS
cardPositionCSS index = do
  CSSUtils.left $ CSSUtils.calc $
    "(100% + " ⊕ show cardSpacingPx ⊕ "px) * " ⊕ show index

cardSliderTransformCSS ∷ Int → Number → CSS
cardSliderTransformCSS activeCardIndex translateX =
  CSSUtils.transform
    $ CSSUtils.translate3d (cardSliderTranslateX activeCardIndex translateX) "0" "0"

cardSliderTransitionCSS ∷ Boolean → CSS
cardSliderTransitionCSS false = CSSUtils.transition "none"
cardSliderTransitionCSS true = CSSUtils.transition "all 0.33s"

cardSliderTranslateX ∷ Int → Number → String
cardSliderTranslateX activeCardIndex translateX =
  CSSUtils.calc
    $ "(-100% - " ⊕ show cardSpacingPx ⊕ "px)"
    ⊕ " * " ⊕ show activeCardIndex
    ⊕ " + " ⊕ show translateX ⊕ "px"

dropEffect ∷ Boolean → String
dropEffect true = "execute"
dropEffect false = "none"

containerProperties
  ∷ ∀ a
  . State
  → Array (IProp (onMouseUp ∷ I, onMouseLeave ∷ I, onMouseMove ∷ I | a) (Query Unit))
containerProperties st =
  [ ARIA.dropEffect $ dropEffect $ willChangeActiveCardWhenDropped st ]
    ⊕ (guard (isJust st.initialSliderX)
         $> (HE.onMouseUp \e →
              HEH.preventDefault
              $> Just (H.action (DCQ.StopSlidingAndSnap e))))
    ⊕ (guard (isJust st.initialSliderX)
         $> (HE.onMouseLeave \e →
              HEH.stopPropagation
              $> HEH.preventDefault
              $> Just (H.action (DCQ.StopSlidingAndSnap e))))
    ⊕ (guard (isJust st.initialSliderX)
         $> (HE.onMouseMove $ HE.input DCQ.UpdateSliderPosition))

cardSelected ∷ State → CardId → Boolean
cardSelected state cardId =
  Just cardId ≡ DCS.activeCardId state

cardProperties ∷ ∀ a b. State → CardId → Array (IProp a b)
cardProperties state cardId =
  [ ARIA.disabled ∘ show ∘ not $ cardSelected state cardId ]

cardSpacingGridSquares ∷ Number
cardSpacingGridSquares = 2.0

cardSpacingPx ∷ Number
cardSpacingPx = cardSpacingGridSquares * Config.gridPx

renderCard ∷ DeckComponent → State → Card.Model → Int → DeckHTML
renderCard comp st card index =
  HH.div
    ([ HP.key ("card" ⊕ CardId.cardIdToString card.cardId)
    , HP.classes [ ClassNames.card ]
    , style $ cardPositionCSS index
    , HP.ref (H.action ∘ DCQ.SetCardElement)
    ])
    $ Gripper.renderGrippers
        (cardSelected st card.cardId)
        (isJust st.initialSliderX)
        (Gripper.gripperDefsForCardId st.displayCards $ Just card.cardId)
        ⊕ [ HH.div
              (cardProperties st card.cardId)
              [ HH.slot' ChildSlot.cpCard slotId \_ → cardComponent ]
           ]
  where
  slotId = ChildSlot.CardSlot card.cardId
  cardComponent =
    { component: cardTypeComponent card.cardType card.cardId comp card.inner
    , initialState:
        H.parentState
          CardC.initialCardState { accessType = st.accessType }
    }
