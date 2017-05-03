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

module SlamData.Workspace.Card.Error.Component
  ( errorCardComponent
  , module SlamData.Workspace.Card.Error.Component.Query
  , module SlamData.Workspace.Card.Error.Component.State
  ) where

import SlamData.Prelude

import Data.Argonaut as J
import Data.Path.Pathy as Path
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Quasar.Advanced.QuasarAF as QA
import SlamData.GlobalError as GE
import SlamData.Monad (Slam)
import SlamData.Render.Icon as I
import SlamData.Wiring as Wiring
import SlamData.Workspace.AccessType (AccessType(..))
import SlamData.Workspace.Card.Error as CE
import SlamData.Workspace.Card.Error (CardError(..), cardToGlobalError)
import SlamData.Workspace.Card.Error.Component.Query (Query(..))
import SlamData.Workspace.Card.Error.Component.State (State, initialState)
import Utils (prettyJson)

type DSL = H.ComponentDSL State Query Void Slam
type HTML = H.ComponentHTML Query

errorCardComponent ∷ H.Component HH.HTML Query CardError Void Slam
errorCardComponent =
  H.lifecycleComponent
    { initialState: initialState
    , render
    , eval
    -- TODO: check whether the card needs to be able to respond to input changes
    -- it may be unnecessary, as I think the error card disappears between runs -gb
    , receiver: const Nothing
    , initializer: Just (H.action Init)
    , finalizer: Nothing
    }

render ∷ State → HTML
render st = prettyPrintCardError st st.error

eval ∷ Query ~> DSL
eval = case _ of
  Init next → do
    { accessType } ← Wiring.expose
    H.modify (_ { accessType = accessType })
    pure next
  ToggleExpanded b next → do
    H.modify (_ { expanded = b })
    pure next

printQErrorWithDetails ∷ QA.QError → HTML
printQErrorWithDetails = case _ of
  err → HH.text (QA.printQError err)

printQErrorDetails ∷ QA.QError → HTML
printQErrorDetails = case _ of
  QA.ErrorMessage { raw } → printQErrorRaw raw
  err → HH.text (QA.printQError err)

printQErrorRaw ∷ J.JObject → HTML
printQErrorRaw raw = HH.pre_ [ HH.text (prettyJson (J.fromObject raw)) ]

prettyPrintCardError ∷ State → CardError → HTML
prettyPrintCardError state ce = case cardToGlobalError ce of
  Just ge → HH.text (GE.print ge)
  Nothing → case ce of
    QuasarError qError → printQErrorWithDetails qError
    StringlyTypedError err → HH.text err
    CacheCardError cce → cacheErrorMessage state cce
    QueryCardError qce → queryErrorMessage state qce
    MarkdownCardError mde → markdownErrorMessage state mde
    DownloadOptionsCardError dloe → downloadOptionsErrorMessage state dloe

collapsible ∷ String → HTML → Boolean → HTML
collapsible title content expanded =
  HH.div
    [ HP.classes [ H.ClassName "sd-collapsible-error" ] ]
    $ join
      [ pure $
          HH.button
            [ HE.onClick $ HE.input_ (ToggleExpanded (not expanded)) ]
            [ if expanded then I.chevronDownSm else I.chevronRightSm
            , HH.span_ [ HH.text title ]
            ]
      , guard expanded $>
          HH.div
            [ HP.class_ (H.ClassName "sd-collapsible-error-content") ]
            [ content ]
      ]

queryErrorMessage ∷ State → CE.QueryError → HTML
queryErrorMessage { accessType, expanded } err =
  case accessType of
    Editable → renderDetails err
    ReadOnly →
      HH.div_
        [ HH.p_ [ HH.text "A problem occurred in the query card, please notify the author of this workspace." ]
        , collapsible "Error details" (renderDetails err) expanded
        ]
  where
  renderDetails = case _ of
    CE.QueryCompileError qErr →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "An error occurred during query compilation." ]
          , renderMore qErr
          ]
    CE.QueryRetrieveResultError qErr →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "An error occurred when retrieving the query result." ]
          , renderMore qErr
          ]
  renderMore = case _ of
    QA.ErrorMessage {title, message, raw} →
      pure $ HH.div_
        $ join
          [ foldMap (\t -> pure $ HH.p_ [ HH.text t ]) title
          , pure $ HH.p_ [ HH.text message ]
          , guard (accessType == Editable) $> collapsible "Quasar error details" (printQErrorRaw raw) expanded
          ]
    err' →
      guard (accessType == Editable) $> collapsible "Quasar error details" (printQErrorDetails err') expanded

cacheErrorMessage ∷ State → CE.CacheError → HTML
cacheErrorMessage { accessType, expanded } err =
  case accessType of
    Editable → renderDetails err
    ReadOnly →
      HH.div_
        [ HH.p_ [ HH.text "A problem occurred in the cache card, please notify the author of this workspace." ]
        , collapsible "Error details" (renderDetails err) expanded
        ]
  where
  renderDetails = case _ of
    CE.CacheInvalidFilepath fp →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "There is a problem in the configuration of the cache card." ]
          , pure $ HH.p_
              [ HH.text "The provided path "
              , HH.code_ [ HH.text fp ]
              , HH.text " is not a valid location to store the cache result."
              ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.CacheQuasarError qe →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ I.warningSm, HH.text " Caching the result of a query failed." ]
          , pure $ HH.p_ [ HH.text "The Quasar analytics engine returned an error while verifying the cache result." ]
          , guard (accessType == Editable) $> collapsible "Quasar error details" (printQErrorDetails qe) expanded
          ]
    CE.CacheErrorSavingFile fp →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "Caching the result of a query failed." ]
          , pure $ HH.p_
              [ HH.text "The file "
              , HH.code_ [ HH.text (Path.printPath fp) ]
              , HH.text " could not be written to."
              ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card and provide an alternative path to fix this error." ]
          ]
    CE.CacheResourceNotModified →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "Caching the result of a query failed." ]
          , pure $ HH.p_ [ HH.text "Caching can only be applied to queries that perform at least one transformation on an existing data set." ]
          -- TODO: only show this solution when there are no following cards?
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card and delete it to fix this error." ]
          ]

markdownErrorMessage ∷ State → CE.MarkdownError → HTML
markdownErrorMessage { accessType, expanded } err =
  case accessType of
    Editable → renderDetails err
    ReadOnly →
      HH.div_
        [ HH.p_ [ HH.text "A problem occurred in the markdown card, please notify the author of this workspace." ]
        , collapsible "Error details" (renderDetails err) expanded
        ]
  where
  renderDetails = case _ of
    CE.MarkdownParseError {markdown, error} →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "Parsing the provided Markdown failed." ]
          , pure $ HH.p_
              [ HH.text "We encountered the following parse error: "
              , HH.code_ [ HH.text error ]
              ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.MarkdownSqlParseError {sql, error} →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "Parsing SQL embedded inside Markdown failed." ]
          , pure $ renderParseError error sql
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.MarkdownNoTextBoxResults →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "A text box field did not return any results." ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.MarkdownInvalidTimeValue { time, error } →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "An invalid time value was provided." ]
          , pure $ renderParseError error time
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.MarkdownInvalidDateValue { date, error } →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "An invalid date value was provided." ]
          , pure $ renderParseError error date
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.MarkdownInvalidDateTimeValue { datetime, error } →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "An invalid datetime value was provided." ]
          , pure $ renderParseError error datetime
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.MarkdownTypeError t1 t2 →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "An type mismatch occurred." ]
          , pure $ HH.p_
              [ HH.text "We encountered the following type:"
              , HH.br_
              , HH.code_ [ HH.text t1 ]
              , HH.text " where we expected:"
              , HH.br_
              , HH.code_ [ HH.text t2 ]
              ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    where
      renderParseError error value =
        HH.p_
          [ HH.text "We encountered the following error:"
          , HH.br_
          , HH.code_ [ HH.text error ]
          , HH.text " when trying to parse:"
          , HH.br_
          , HH.code_ [ HH.text value ]
          ]

downloadOptionsErrorMessage ∷ State → CE.DownloadOptionsError → HTML
downloadOptionsErrorMessage { accessType, expanded } err =
  case accessType of
    Editable → renderDetails err
    ReadOnly →
      HH.div_
        [ HH.p_ [ HH.text "A problem occurred in the download options card, please notify the author of this workspace." ]
        , collapsible "Error details" (renderDetails err) expanded
        ]
  where
  renderDetails = case _ of
    CE.DownloadOptionsFilenameRequired →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "No filename was provided." ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
    CE.DownloadOptionsFilenameInvalid fn →
      HH.div_
        $ join
          [ pure $ HH.h1_ [ HH.text "The provided filename was invalid." ]
          , pure $ HH.p_
              [ HH.code_ [ HH.text fn ], HH.text " is not a valid filepath." ]
          , guard (accessType == Editable) $> HH.p_ [ HH.text "Go back to the previous card to fix this error." ]
          ]
