# Keygram Keyboard Dry Run

This file explains, in simple terms, how the custom keyboard works from launch to typing, suggestions, autocorrect, emoji mode, and learning.

## Main Parts

- `AtlasKeyboard/KeyboardViewController.swift` is the brain of the keyboard extension.
  It talks to iOS through `UIInputViewController`, inserts and deletes text with `textDocumentProxy`, runs autocorrect, refreshes suggestions, and saves learning data.

- `AtlasKeyboard/KeyboardSurfaceView.swift` is the keyboard UI.
  It draws the suggestion bar, key rows, emoji panel, haptics/menu controls, key previews, and sends tap events back to the controller through `KeyboardSurfaceViewDelegate`.

- `AtlasCore/AtlasAutocorrectEngine.swift` decides spelling corrections and completions using the compiled lexicon, frequency data, personal words, and feedback.

- `AtlasCore/AtlasInferenceEngine.swift` ranks next-word suggestions and completions. In the keyboard extension, it now tries to use the bundled ONNX model and falls back to vocabulary/frequency suggestions if the runtime or model cannot load.

- `AtlasCore/KeygramDecoder.swift`, `TouchModel.swift`, and `TouchModelStore.swift` handle personalized touch learning. They learn where the user tends to tap and can later resolve near-miss taps if personalized typing is enabled.

- `AtlasCore/Engram.swift` stores learned personal words and uses them to bias suggestions and autocorrect.

- `AtlasCore/AtlasSessionStore.swift` saves the single user session, including the learned `Engram` and model state, in the app group container.

## Startup Dry Run

1. iOS loads the keyboard extension and creates `KeyboardViewController`.

2. `loadView()` creates a transparent `UIInputView`, sets its height to `KeyboardSurfaceView.preferredKeyboardHeight`, and prepares the keyboard to self-size.

3. `viewWillAppear()` installs a fresh `KeyboardSurfaceView` if one is not already present.

4. `installFreshKeyboardSurface()` creates the UI surface, attaches it to the controller view, sets the delegate, and applies current state:
   - active persona/session name
   - return key type
   - shift/caps state
   - current suggestions

5. `viewDidAppear()` starts loading autocorrect in the background.

6. `AutocorrectService.shared.loadIfNeeded()` builds one shared `AtlasAutocorrectEngine`, caches it, then gives it back to the controller.

7. The controller runs any needed engram migration, refreshes live autocorrect, and refreshes suggestions.

8. `viewDidLayoutSubviews()` calls `configureTouchDecoderIfNeeded()`. Once the keyboard has real bounds and all 26 letter keys are visible, it builds or loads the personalized touch model.

## Keyboard UI Dry Run

1. `KeyboardSurfaceView.build()` creates three main visual areas:
   - `backgroundPanel`
   - `rootStack`
   - `menuOverlay`

2. `rootStack` is vertical and has two slots:
   - `toolbarSlot`: suggestion bar and persona button
   - `keyAreaSlot`: letters, numbers, symbols, or emoji UI

3. The normal letter layout is QWERTY:
   - row 1: `qwertyuiop`
   - row 2: `asdfghjkl`
   - row 3: shift, `zxcvbnm`, backspace
   - row 4: mode toggle, emoji/globe, space, return

4. The `123` key toggles between letters and numbers.

5. The `#+=` key toggles between numbers and symbols.

6. The globe/emoji key switches into emoji mode.

7. When a key is pressed:
   - haptic feedback runs if enabled
   - character keys show a small key preview
   - the surface records touch-down and touch-up timing
   - the surface sends the key, tap point, and timing to the controller

## Typing A Letter Dry Run

Example: user taps `h`.

1. `KeyboardSurfaceView.keyTapped()` receives the button tap.

2. It gets the actual tap point in keyboard-local coordinates.

3. It calls:

   ```swift
   delegate?.keyboardSurfaceView(self, didTap: sender.key, at: tapPoint, ...)
   ```

4. `KeyboardViewController.keyboardSurfaceView(_:didTap:at:...)` receives `.character("h")`.

5. The controller calls `resolvedTouchCharacter(for:at:)`.

6. If personalized typing is off, not ready, or not confident, the visible key stays `"h"`.

7. If personalized typing is on and the model has enough learned taps, `KeygramDecoder` can replace the visible key with a better guess only when the tap is clearly outside the visible key and another key is much more likely.

8. The controller calls `insert(...)`.

9. `insert(...)` first accepts any pending autocorrection feedback if needed.

10. It applies shift/caps if active.

11. It inserts text into the host app with:

    ```swift
    textDocumentProxy.insertText(text)
    ```

12. It appends the character to `currentDraftText`.

13. It appends the character to `LiveWordDecoder`, which keeps the current word for live autocorrect.

14. If shift was a one-time shift, it turns shift off.

15. It refreshes live autocorrect and schedules suggestion refresh.

## Space Key And Autocorrect Dry Run

Example: user types `teh` then taps space.

1. Each letter is inserted immediately, so the text field shows `teh`.

2. `LiveWordDecoder` has been tracking the raw word `teh`.

3. While typing, `refreshLiveAutocorrect()` may already ask `AtlasAutocorrectEngine` whether `teh` should become `the`.

4. When the user taps space, the controller:
   - saves the context before the space
   - finds the last typed word
   - checks whether `LiveWordDecoder` already has a confident cached decision
   - inserts the space immediately

5. The tap is committed to the touch model as a word boundary.

6. If the live decision is confident and still matches the typed word, the controller applies it immediately.

7. If no live decision is available, `scheduleAutocorrectAfterSpace()` runs autocorrect on a background queue.

8. `AtlasAutocorrectEngine.correction(...)` checks:
   - whether the word is eligible
   - dictionary candidates
   - keyboard-distance typo likelihood
   - word frequency
   - personal words from `Engram`
   - accepted/rejected autocorrect feedback
   - split-word corrections

9. If a good correction is found quickly enough, `applyAutocorrectDecisionAfterSpace()` verifies that the current text still ends with the original word plus a space.

10. It deletes the original suffix using `textDocumentProxy.deleteBackward()`.

11. It inserts the corrected word plus a space.

12. It shows an undo suggestion pill like:

    ```text
    Undo "teh->the"
    ```

13. It stores the correction as pending feedback. If the user keeps typing, the correction is considered accepted. If the user undoes it, the correction is considered rejected.

## Undo Autocorrect Dry Run

1. After autocorrect applies, the suggestion bar temporarily shows an undo pill.

2. If the user taps the undo pill, `acceptSuggestion(...)` sees `.undoAutocorrection`.

3. `undoLastAutocorrection(...)` checks whether the current text still ends with the corrected word.

4. It deletes the corrected word.

5. It inserts the original word.

6. It records rejected feedback so the same correction is less likely next time.

7. It learns the original word as something the user may intend.

## Suggestion Bar Dry Run

1. Text changes call `textDidChange(...)`.

2. The controller schedules `refreshSuggestions()` with a short delay.

3. If inference suggestions are disabled or the engine is not loaded yet, the keyboard uses lightweight suggestions:
   - it detects the current partial word
   - it asks `AtlasAutocorrectEngine.completions(...)`
   - it displays up to `AtlasConfiguration.maxSuggestions`, currently 3

4. If inference suggestions are enabled, the controller lazily loads `AtlasInferenceEngine`.

5. `AtlasInferenceEngine.suggestions(...)` tokenizes the recent context and ranks candidates.

6. For next-word prediction after a word boundary, the keyboard passes the last 10 words of context into the inference engine. If the ONNX runtime loads successfully, model logits are used; otherwise the engine falls back to vocabulary/frequency scores.

7. `AtlasSuggestionRanker` combines candidate scores with personal `Engram` bias and returns top suggestions.

8. `KeyboardSurfaceView.setSuggestions(...)` updates the three suggestion buttons.

## Tapping A Suggestion Dry Run

Example: user typed `hel` and taps suggestion `hello`.

1. `KeyboardSurfaceView.suggestionTapped(...)` reads the suggestion text and kind.

2. It sends `didAccept` to the controller.

3. `KeyboardViewController.acceptSuggestion(...)` handles the selected suggestion.

4. If it is a completion and the current partial word is replaceable:
   - delete the partial word from the host text field
   - insert the full suggestion plus a trailing space
   - update `currentDraftText`

5. If it is a correction for selected text, it inserts the correction.

6. Otherwise it inserts the suggestion plus a trailing space.

7. The accepted suggestion is learned into the active session's `Engram`.

8. Suggestions are refreshed.

## Backspace Dry Run

1. A normal backspace tap first tells `touchDecoder` to forget the latest pending tap. This prevents learning from a character the user immediately deleted.

2. The controller tries to undo the last autocorrection if the current text matches the corrected word.

3. If there is no autocorrection to undo, it calls `textDocumentProxy.deleteBackward()`.

4. It removes the last character from `currentDraftText`.

5. It updates `LiveWordDecoder`.

6. It refreshes live autocorrect and suggestions.

7. A long press on backspace starts a timer that repeatedly calls the delegate's long-press delete handler.

## Shift And Caps Lock Dry Run

1. A single shift tap turns `isShifted` on.

2. The next typed character is uppercased.

3. After that character, `consumeOneShotShiftIfNeeded()` turns shift back off.

4. A quick double tap on shift enables caps lock.

5. Tapping shift while shifted or caps locked turns shift/caps off.

6. `KeyboardSurfaceView.setShiftState(...)` updates visible key titles and the shift icon.

## Return Key Dry Run

1. Return commits the current touch word boundary.

2. It accepts any pending autocorrection feedback.

3. It inserts a newline with `textDocumentProxy.insertText("\n")`.

4. It resets live word decoding.

5. `endCurrentDraft()` learns the completed draft message into `Engram`, resets inference draft memory, clears `currentDraftText`, and refreshes suggestions.

## Emoji Mode Dry Run

1. The user taps the globe/emoji key.

2. `KeyboardSurfaceView` switches `keyboardMode` to `.emoji` and rebuilds rows.

3. In emoji mode the toolbar is hidden and the keyboard height grows.

4. The emoji UI can show:
   - search row
   - emoji grid
   - category strip
   - engram/persona-style grid
   - emoji mode toolbar

5. Tapping an emoji from the collection view sends `.character(emoji)` to the controller.

6. The controller inserts the emoji like any other character.

7. Recent emojis are kept in memory inside `KeyboardSurfaceView` and shown first when available.

8. Emoji search mode uses its own mini QWERTY layout. Typing there updates `emojiSearchQuery` instead of inserting into the host app.

## Personalized Touch Learning Dry Run

1. After layout is stable, the controller asks the surface for `touchModelLayoutSnapshot()`.

2. The snapshot contains key IDs and actual frames for visible letter keys.

3. `TouchModelStore` tries to load a saved model from the app group.

4. If no model exists, `TouchModel` starts with one Gaussian per key based on the key's visual center and size.

5. Each letter tap is buffered in `KeygramDecoder`.

6. The model does not immediately learn every tap. It waits until the word is committed.

7. When a word boundary happens, `commitPendingWord(...)` labels the buffered taps:
   - if autocorrect produced a same-length final word, use the corrected word as labels
   - otherwise use the visible/live guesses
   - if lengths do not match, skip learning that word to avoid bad labels

8. Each labeled tap updates the matching key's Gaussian.

9. The model is saved after committed words.

10. Personalized typing only changes typed letters when:
    - the setting is enabled
    - enough taps have been learned, currently 1000
    - the full letter layout is available
    - the model is confident enough to override the visible key

## Personal Word Learning Dry Run

1. Accepted suggestions are learned immediately with `learn(...)`.

2. Completed draft text is learned when return/end is pressed.

3. Typed words that are not dictionary words may be observed and promoted over time.

4. Accepted autocorrections demote the mistyped original and learn the replacement.

5. Rejected autocorrections record feedback and learn the original.

6. `Engram` only strongly biases suggestions and autocorrect after words become confirmed.

## Field Safety Dry Run

Autocorrect is skipped when:

- the user setting disables autocorrect
- the keyboard type is URL, email, web search, name/phone pad, or phone pad
- the text field has `autocorrectionType == .no`

This avoids changing text in fields where corrections are usually harmful.

## One Full Example

User types `teh `:

1. Tap `t`: surface sends key and point, controller inserts `t`, live decoder tracks `t`.

2. Tap `e`: controller inserts `e`, live decoder tracks `te`.

3. Tap `h`: controller inserts `h`, live decoder tracks `teh`, live autocorrect may cache `teh -> the`.

4. Tap space: controller inserts a space immediately.

5. If cached correction is valid, it deletes `teh ` and inserts `the `.

6. Suggestion bar shows undo for about 2 seconds.

7. If user continues typing, `teh -> the` is recorded as accepted feedback and `the` is learned.

8. If user taps undo/backspace immediately, `the ` is replaced with `teh ` and rejected feedback is saved.

## Short Mental Model

The surface view is the keyboard body. The controller is the keyboard brain. The autocorrect engine fixes words. The suggestion engine fills the suggestion bar. The touch model learns where the user taps. The engram learns what the user writes. The session store saves all personal state.
