// Generated from Unicode emoji-test.txt v17.0 (2025-08-04).
// Source: https://unicode.org/Public/emoji/latest/emoji-test.txt
import Foundation

struct EmojiCatalogItem {
    let value: String
    let name: String
    let subgroup: String
}

struct EmojiCatalogCategory {
    let name: String
    let symbolName: String
    let items: [EmojiCatalogItem]
}

enum EmojiCatalog {
    private static let rawData = #"""
@Smileys & Emotion	face.smiling
😀	grinning face	face-smiling
😃	grinning face with big eyes	face-smiling
😄	grinning face with smiling eyes	face-smiling
😁	beaming face with smiling eyes	face-smiling
😆	grinning squinting face	face-smiling
😅	grinning face with sweat	face-smiling
🤣	rolling on the floor laughing	face-smiling
😂	face with tears of joy	face-smiling
🙂	slightly smiling face	face-smiling
🙃	upside-down face	face-smiling
🫠	melting face	face-smiling
😉	winking face	face-smiling
😊	smiling face with smiling eyes	face-smiling
😇	smiling face with halo	face-smiling
🥰	smiling face with hearts	face-affection
😍	smiling face with heart-eyes	face-affection
🤩	star-struck	face-affection
😘	face blowing a kiss	face-affection
😗	kissing face	face-affection
☺️	smiling face	face-affection
😚	kissing face with closed eyes	face-affection
😙	kissing face with smiling eyes	face-affection
🥲	smiling face with tear	face-affection
😋	face savoring food	face-tongue
😛	face with tongue	face-tongue
😜	winking face with tongue	face-tongue
🤪	zany face	face-tongue
😝	squinting face with tongue	face-tongue
🤑	money-mouth face	face-tongue
🤗	smiling face with open hands	face-hand
🤭	face with hand over mouth	face-hand
🫢	face with open eyes and hand over mouth	face-hand
🫣	face with peeking eye	face-hand
🤫	shushing face	face-hand
🤔	thinking face	face-hand
🫡	saluting face	face-hand
🤐	zipper-mouth face	face-neutral-skeptical
🤨	face with raised eyebrow	face-neutral-skeptical
😐	neutral face	face-neutral-skeptical
😑	expressionless face	face-neutral-skeptical
😶	face without mouth	face-neutral-skeptical
🫥	dotted line face	face-neutral-skeptical
😶‍🌫️	face in clouds	face-neutral-skeptical
😏	smirking face	face-neutral-skeptical
😒	unamused face	face-neutral-skeptical
🙄	face with rolling eyes	face-neutral-skeptical
😬	grimacing face	face-neutral-skeptical
😮‍💨	face exhaling	face-neutral-skeptical
🤥	lying face	face-neutral-skeptical
🫨	shaking face	face-neutral-skeptical
🙂‍↔️	head shaking horizontally	face-neutral-skeptical
🙂‍↕️	head shaking vertically	face-neutral-skeptical
😌	relieved face	face-sleepy
😔	pensive face	face-sleepy
😪	sleepy face	face-sleepy
🤤	drooling face	face-sleepy
😴	sleeping face	face-sleepy
🫩	face with bags under eyes	face-sleepy
😷	face with medical mask	face-unwell
🤒	face with thermometer	face-unwell
🤕	face with head-bandage	face-unwell
🤢	nauseated face	face-unwell
🤮	face vomiting	face-unwell
🤧	sneezing face	face-unwell
🥵	hot face	face-unwell
🥶	cold face	face-unwell
🥴	woozy face	face-unwell
😵	face with crossed-out eyes	face-unwell
😵‍💫	face with spiral eyes	face-unwell
🤯	exploding head	face-unwell
🤠	cowboy hat face	face-hat
🥳	partying face	face-hat
🥸	disguised face	face-hat
😎	smiling face with sunglasses	face-glasses
🤓	nerd face	face-glasses
🧐	face with monocle	face-glasses
😕	confused face	face-concerned
🫤	face with diagonal mouth	face-concerned
😟	worried face	face-concerned
🙁	slightly frowning face	face-concerned
☹️	frowning face	face-concerned
😮	face with open mouth	face-concerned
😯	hushed face	face-concerned
😲	astonished face	face-concerned
😳	flushed face	face-concerned
🫪	distorted face	face-concerned
🥺	pleading face	face-concerned
🥹	face holding back tears	face-concerned
😦	frowning face with open mouth	face-concerned
😧	anguished face	face-concerned
😨	fearful face	face-concerned
😰	anxious face with sweat	face-concerned
😥	sad but relieved face	face-concerned
😢	crying face	face-concerned
😭	loudly crying face	face-concerned
😱	face screaming in fear	face-concerned
😖	confounded face	face-concerned
😣	persevering face	face-concerned
😞	disappointed face	face-concerned
😓	downcast face with sweat	face-concerned
😩	weary face	face-concerned
😫	tired face	face-concerned
🥱	yawning face	face-concerned
😤	face with steam from nose	face-negative
😡	enraged face	face-negative
😠	angry face	face-negative
🤬	face with symbols on mouth	face-negative
😈	smiling face with horns	face-negative
👿	angry face with horns	face-negative
💀	skull	face-negative
☠️	skull and crossbones	face-negative
💩	pile of poo	face-costume
🤡	clown face	face-costume
👹	ogre	face-costume
👺	goblin	face-costume
👻	ghost	face-costume
👽	alien	face-costume
👾	alien monster	face-costume
🤖	robot	face-costume
😺	grinning cat	cat-face
😸	grinning cat with smiling eyes	cat-face
😹	cat with tears of joy	cat-face
😻	smiling cat with heart-eyes	cat-face
😼	cat with wry smile	cat-face
😽	kissing cat	cat-face
🙀	weary cat	cat-face
😿	crying cat	cat-face
😾	pouting cat	cat-face
🙈	see-no-evil monkey	monkey-face
🙉	hear-no-evil monkey	monkey-face
🙊	speak-no-evil monkey	monkey-face
💌	love letter	heart
💘	heart with arrow	heart
💝	heart with ribbon	heart
💖	sparkling heart	heart
💗	growing heart	heart
💓	beating heart	heart
💞	revolving hearts	heart
💕	two hearts	heart
💟	heart decoration	heart
❣️	heart exclamation	heart
💔	broken heart	heart
❤️‍🔥	heart on fire	heart
❤️‍🩹	mending heart	heart
❤️	red heart	heart
🩷	pink heart	heart
🧡	orange heart	heart
💛	yellow heart	heart
💚	green heart	heart
💙	blue heart	heart
🩵	light blue heart	heart
💜	purple heart	heart
🤎	brown heart	heart
🖤	black heart	heart
🩶	grey heart	heart
🤍	white heart	heart
💋	kiss mark	emotion
💯	hundred points	emotion
💢	anger symbol	emotion
🫯	fight cloud	emotion
💥	collision	emotion
💫	dizzy	emotion
💦	sweat droplets	emotion
💨	dashing away	emotion
🕳️	hole	emotion
💬	speech balloon	emotion
👁️‍🗨️	eye in speech bubble	emotion
🗨️	left speech bubble	emotion
🗯️	right anger bubble	emotion
💭	thought balloon	emotion
💤	ZZZ	emotion
@People & Body	hand.raised.fill
👋	waving hand	hand-fingers-open
👋🏻	waving hand: light skin tone	hand-fingers-open
👋🏼	waving hand: medium-light skin tone	hand-fingers-open
👋🏽	waving hand: medium skin tone	hand-fingers-open
👋🏾	waving hand: medium-dark skin tone	hand-fingers-open
👋🏿	waving hand: dark skin tone	hand-fingers-open
🤚	raised back of hand	hand-fingers-open
🤚🏻	raised back of hand: light skin tone	hand-fingers-open
🤚🏼	raised back of hand: medium-light skin tone	hand-fingers-open
🤚🏽	raised back of hand: medium skin tone	hand-fingers-open
🤚🏾	raised back of hand: medium-dark skin tone	hand-fingers-open
🤚🏿	raised back of hand: dark skin tone	hand-fingers-open
🖐️	hand with fingers splayed	hand-fingers-open
🖐🏻	hand with fingers splayed: light skin tone	hand-fingers-open
🖐🏼	hand with fingers splayed: medium-light skin tone	hand-fingers-open
🖐🏽	hand with fingers splayed: medium skin tone	hand-fingers-open
🖐🏾	hand with fingers splayed: medium-dark skin tone	hand-fingers-open
🖐🏿	hand with fingers splayed: dark skin tone	hand-fingers-open
✋	raised hand	hand-fingers-open
✋🏻	raised hand: light skin tone	hand-fingers-open
✋🏼	raised hand: medium-light skin tone	hand-fingers-open
✋🏽	raised hand: medium skin tone	hand-fingers-open
✋🏾	raised hand: medium-dark skin tone	hand-fingers-open
✋🏿	raised hand: dark skin tone	hand-fingers-open
🖖	vulcan salute	hand-fingers-open
🖖🏻	vulcan salute: light skin tone	hand-fingers-open
🖖🏼	vulcan salute: medium-light skin tone	hand-fingers-open
🖖🏽	vulcan salute: medium skin tone	hand-fingers-open
🖖🏾	vulcan salute: medium-dark skin tone	hand-fingers-open
🖖🏿	vulcan salute: dark skin tone	hand-fingers-open
🫱	rightwards hand	hand-fingers-open
🫱🏻	rightwards hand: light skin tone	hand-fingers-open
🫱🏼	rightwards hand: medium-light skin tone	hand-fingers-open
🫱🏽	rightwards hand: medium skin tone	hand-fingers-open
🫱🏾	rightwards hand: medium-dark skin tone	hand-fingers-open
🫱🏿	rightwards hand: dark skin tone	hand-fingers-open
🫲	leftwards hand	hand-fingers-open
🫲🏻	leftwards hand: light skin tone	hand-fingers-open
🫲🏼	leftwards hand: medium-light skin tone	hand-fingers-open
🫲🏽	leftwards hand: medium skin tone	hand-fingers-open
🫲🏾	leftwards hand: medium-dark skin tone	hand-fingers-open
🫲🏿	leftwards hand: dark skin tone	hand-fingers-open
🫳	palm down hand	hand-fingers-open
🫳🏻	palm down hand: light skin tone	hand-fingers-open
🫳🏼	palm down hand: medium-light skin tone	hand-fingers-open
🫳🏽	palm down hand: medium skin tone	hand-fingers-open
🫳🏾	palm down hand: medium-dark skin tone	hand-fingers-open
🫳🏿	palm down hand: dark skin tone	hand-fingers-open
🫴	palm up hand	hand-fingers-open
🫴🏻	palm up hand: light skin tone	hand-fingers-open
🫴🏼	palm up hand: medium-light skin tone	hand-fingers-open
🫴🏽	palm up hand: medium skin tone	hand-fingers-open
🫴🏾	palm up hand: medium-dark skin tone	hand-fingers-open
🫴🏿	palm up hand: dark skin tone	hand-fingers-open
🫷	leftwards pushing hand	hand-fingers-open
🫷🏻	leftwards pushing hand: light skin tone	hand-fingers-open
🫷🏼	leftwards pushing hand: medium-light skin tone	hand-fingers-open
🫷🏽	leftwards pushing hand: medium skin tone	hand-fingers-open
🫷🏾	leftwards pushing hand: medium-dark skin tone	hand-fingers-open
🫷🏿	leftwards pushing hand: dark skin tone	hand-fingers-open
🫸	rightwards pushing hand	hand-fingers-open
🫸🏻	rightwards pushing hand: light skin tone	hand-fingers-open
🫸🏼	rightwards pushing hand: medium-light skin tone	hand-fingers-open
🫸🏽	rightwards pushing hand: medium skin tone	hand-fingers-open
🫸🏾	rightwards pushing hand: medium-dark skin tone	hand-fingers-open
🫸🏿	rightwards pushing hand: dark skin tone	hand-fingers-open
👌	OK hand	hand-fingers-partial
👌🏻	OK hand: light skin tone	hand-fingers-partial
👌🏼	OK hand: medium-light skin tone	hand-fingers-partial
👌🏽	OK hand: medium skin tone	hand-fingers-partial
👌🏾	OK hand: medium-dark skin tone	hand-fingers-partial
👌🏿	OK hand: dark skin tone	hand-fingers-partial
🤌	pinched fingers	hand-fingers-partial
🤌🏻	pinched fingers: light skin tone	hand-fingers-partial
🤌🏼	pinched fingers: medium-light skin tone	hand-fingers-partial
🤌🏽	pinched fingers: medium skin tone	hand-fingers-partial
🤌🏾	pinched fingers: medium-dark skin tone	hand-fingers-partial
🤌🏿	pinched fingers: dark skin tone	hand-fingers-partial
🤏	pinching hand	hand-fingers-partial
🤏🏻	pinching hand: light skin tone	hand-fingers-partial
🤏🏼	pinching hand: medium-light skin tone	hand-fingers-partial
🤏🏽	pinching hand: medium skin tone	hand-fingers-partial
🤏🏾	pinching hand: medium-dark skin tone	hand-fingers-partial
🤏🏿	pinching hand: dark skin tone	hand-fingers-partial
✌️	victory hand	hand-fingers-partial
✌🏻	victory hand: light skin tone	hand-fingers-partial
✌🏼	victory hand: medium-light skin tone	hand-fingers-partial
✌🏽	victory hand: medium skin tone	hand-fingers-partial
✌🏾	victory hand: medium-dark skin tone	hand-fingers-partial
✌🏿	victory hand: dark skin tone	hand-fingers-partial
🤞	crossed fingers	hand-fingers-partial
🤞🏻	crossed fingers: light skin tone	hand-fingers-partial
🤞🏼	crossed fingers: medium-light skin tone	hand-fingers-partial
🤞🏽	crossed fingers: medium skin tone	hand-fingers-partial
🤞🏾	crossed fingers: medium-dark skin tone	hand-fingers-partial
🤞🏿	crossed fingers: dark skin tone	hand-fingers-partial
🫰	hand with index finger and thumb crossed	hand-fingers-partial
🫰🏻	hand with index finger and thumb crossed: light skin tone	hand-fingers-partial
🫰🏼	hand with index finger and thumb crossed: medium-light skin tone	hand-fingers-partial
🫰🏽	hand with index finger and thumb crossed: medium skin tone	hand-fingers-partial
🫰🏾	hand with index finger and thumb crossed: medium-dark skin tone	hand-fingers-partial
🫰🏿	hand with index finger and thumb crossed: dark skin tone	hand-fingers-partial
🤟	love-you gesture	hand-fingers-partial
🤟🏻	love-you gesture: light skin tone	hand-fingers-partial
🤟🏼	love-you gesture: medium-light skin tone	hand-fingers-partial
🤟🏽	love-you gesture: medium skin tone	hand-fingers-partial
🤟🏾	love-you gesture: medium-dark skin tone	hand-fingers-partial
🤟🏿	love-you gesture: dark skin tone	hand-fingers-partial
🤘	sign of the horns	hand-fingers-partial
🤘🏻	sign of the horns: light skin tone	hand-fingers-partial
🤘🏼	sign of the horns: medium-light skin tone	hand-fingers-partial
🤘🏽	sign of the horns: medium skin tone	hand-fingers-partial
🤘🏾	sign of the horns: medium-dark skin tone	hand-fingers-partial
🤘🏿	sign of the horns: dark skin tone	hand-fingers-partial
🤙	call me hand	hand-fingers-partial
🤙🏻	call me hand: light skin tone	hand-fingers-partial
🤙🏼	call me hand: medium-light skin tone	hand-fingers-partial
🤙🏽	call me hand: medium skin tone	hand-fingers-partial
🤙🏾	call me hand: medium-dark skin tone	hand-fingers-partial
🤙🏿	call me hand: dark skin tone	hand-fingers-partial
👈	backhand index pointing left	hand-single-finger
👈🏻	backhand index pointing left: light skin tone	hand-single-finger
👈🏼	backhand index pointing left: medium-light skin tone	hand-single-finger
👈🏽	backhand index pointing left: medium skin tone	hand-single-finger
👈🏾	backhand index pointing left: medium-dark skin tone	hand-single-finger
👈🏿	backhand index pointing left: dark skin tone	hand-single-finger
👉	backhand index pointing right	hand-single-finger
👉🏻	backhand index pointing right: light skin tone	hand-single-finger
👉🏼	backhand index pointing right: medium-light skin tone	hand-single-finger
👉🏽	backhand index pointing right: medium skin tone	hand-single-finger
👉🏾	backhand index pointing right: medium-dark skin tone	hand-single-finger
👉🏿	backhand index pointing right: dark skin tone	hand-single-finger
👆	backhand index pointing up	hand-single-finger
👆🏻	backhand index pointing up: light skin tone	hand-single-finger
👆🏼	backhand index pointing up: medium-light skin tone	hand-single-finger
👆🏽	backhand index pointing up: medium skin tone	hand-single-finger
👆🏾	backhand index pointing up: medium-dark skin tone	hand-single-finger
👆🏿	backhand index pointing up: dark skin tone	hand-single-finger
🖕	middle finger	hand-single-finger
🖕🏻	middle finger: light skin tone	hand-single-finger
🖕🏼	middle finger: medium-light skin tone	hand-single-finger
🖕🏽	middle finger: medium skin tone	hand-single-finger
🖕🏾	middle finger: medium-dark skin tone	hand-single-finger
🖕🏿	middle finger: dark skin tone	hand-single-finger
👇	backhand index pointing down	hand-single-finger
👇🏻	backhand index pointing down: light skin tone	hand-single-finger
👇🏼	backhand index pointing down: medium-light skin tone	hand-single-finger
👇🏽	backhand index pointing down: medium skin tone	hand-single-finger
👇🏾	backhand index pointing down: medium-dark skin tone	hand-single-finger
👇🏿	backhand index pointing down: dark skin tone	hand-single-finger
☝️	index pointing up	hand-single-finger
☝🏻	index pointing up: light skin tone	hand-single-finger
☝🏼	index pointing up: medium-light skin tone	hand-single-finger
☝🏽	index pointing up: medium skin tone	hand-single-finger
☝🏾	index pointing up: medium-dark skin tone	hand-single-finger
☝🏿	index pointing up: dark skin tone	hand-single-finger
🫵	index pointing at the viewer	hand-single-finger
🫵🏻	index pointing at the viewer: light skin tone	hand-single-finger
🫵🏼	index pointing at the viewer: medium-light skin tone	hand-single-finger
🫵🏽	index pointing at the viewer: medium skin tone	hand-single-finger
🫵🏾	index pointing at the viewer: medium-dark skin tone	hand-single-finger
🫵🏿	index pointing at the viewer: dark skin tone	hand-single-finger
👍	thumbs up	hand-fingers-closed
👍🏻	thumbs up: light skin tone	hand-fingers-closed
👍🏼	thumbs up: medium-light skin tone	hand-fingers-closed
👍🏽	thumbs up: medium skin tone	hand-fingers-closed
👍🏾	thumbs up: medium-dark skin tone	hand-fingers-closed
👍🏿	thumbs up: dark skin tone	hand-fingers-closed
👎	thumbs down	hand-fingers-closed
👎🏻	thumbs down: light skin tone	hand-fingers-closed
👎🏼	thumbs down: medium-light skin tone	hand-fingers-closed
👎🏽	thumbs down: medium skin tone	hand-fingers-closed
👎🏾	thumbs down: medium-dark skin tone	hand-fingers-closed
👎🏿	thumbs down: dark skin tone	hand-fingers-closed
✊	raised fist	hand-fingers-closed
✊🏻	raised fist: light skin tone	hand-fingers-closed
✊🏼	raised fist: medium-light skin tone	hand-fingers-closed
✊🏽	raised fist: medium skin tone	hand-fingers-closed
✊🏾	raised fist: medium-dark skin tone	hand-fingers-closed
✊🏿	raised fist: dark skin tone	hand-fingers-closed
👊	oncoming fist	hand-fingers-closed
👊🏻	oncoming fist: light skin tone	hand-fingers-closed
👊🏼	oncoming fist: medium-light skin tone	hand-fingers-closed
👊🏽	oncoming fist: medium skin tone	hand-fingers-closed
👊🏾	oncoming fist: medium-dark skin tone	hand-fingers-closed
👊🏿	oncoming fist: dark skin tone	hand-fingers-closed
🤛	left-facing fist	hand-fingers-closed
🤛🏻	left-facing fist: light skin tone	hand-fingers-closed
🤛🏼	left-facing fist: medium-light skin tone	hand-fingers-closed
🤛🏽	left-facing fist: medium skin tone	hand-fingers-closed
🤛🏾	left-facing fist: medium-dark skin tone	hand-fingers-closed
🤛🏿	left-facing fist: dark skin tone	hand-fingers-closed
🤜	right-facing fist	hand-fingers-closed
🤜🏻	right-facing fist: light skin tone	hand-fingers-closed
🤜🏼	right-facing fist: medium-light skin tone	hand-fingers-closed
🤜🏽	right-facing fist: medium skin tone	hand-fingers-closed
🤜🏾	right-facing fist: medium-dark skin tone	hand-fingers-closed
🤜🏿	right-facing fist: dark skin tone	hand-fingers-closed
👏	clapping hands	hands
👏🏻	clapping hands: light skin tone	hands
👏🏼	clapping hands: medium-light skin tone	hands
👏🏽	clapping hands: medium skin tone	hands
👏🏾	clapping hands: medium-dark skin tone	hands
👏🏿	clapping hands: dark skin tone	hands
🙌	raising hands	hands
🙌🏻	raising hands: light skin tone	hands
🙌🏼	raising hands: medium-light skin tone	hands
🙌🏽	raising hands: medium skin tone	hands
🙌🏾	raising hands: medium-dark skin tone	hands
🙌🏿	raising hands: dark skin tone	hands
🫶	heart hands	hands
🫶🏻	heart hands: light skin tone	hands
🫶🏼	heart hands: medium-light skin tone	hands
🫶🏽	heart hands: medium skin tone	hands
🫶🏾	heart hands: medium-dark skin tone	hands
🫶🏿	heart hands: dark skin tone	hands
👐	open hands	hands
👐🏻	open hands: light skin tone	hands
👐🏼	open hands: medium-light skin tone	hands
👐🏽	open hands: medium skin tone	hands
👐🏾	open hands: medium-dark skin tone	hands
👐🏿	open hands: dark skin tone	hands
🤲	palms up together	hands
🤲🏻	palms up together: light skin tone	hands
🤲🏼	palms up together: medium-light skin tone	hands
🤲🏽	palms up together: medium skin tone	hands
🤲🏾	palms up together: medium-dark skin tone	hands
🤲🏿	palms up together: dark skin tone	hands
🤝	handshake	hands
🤝🏻	handshake: light skin tone	hands
🤝🏼	handshake: medium-light skin tone	hands
🤝🏽	handshake: medium skin tone	hands
🤝🏾	handshake: medium-dark skin tone	hands
🤝🏿	handshake: dark skin tone	hands
🫱🏻‍🫲🏼	handshake: light skin tone, medium-light skin tone	hands
🫱🏻‍🫲🏽	handshake: light skin tone, medium skin tone	hands
🫱🏻‍🫲🏾	handshake: light skin tone, medium-dark skin tone	hands
🫱🏻‍🫲🏿	handshake: light skin tone, dark skin tone	hands
🫱🏼‍🫲🏻	handshake: medium-light skin tone, light skin tone	hands
🫱🏼‍🫲🏽	handshake: medium-light skin tone, medium skin tone	hands
🫱🏼‍🫲🏾	handshake: medium-light skin tone, medium-dark skin tone	hands
🫱🏼‍🫲🏿	handshake: medium-light skin tone, dark skin tone	hands
🫱🏽‍🫲🏻	handshake: medium skin tone, light skin tone	hands
🫱🏽‍🫲🏼	handshake: medium skin tone, medium-light skin tone	hands
🫱🏽‍🫲🏾	handshake: medium skin tone, medium-dark skin tone	hands
🫱🏽‍🫲🏿	handshake: medium skin tone, dark skin tone	hands
🫱🏾‍🫲🏻	handshake: medium-dark skin tone, light skin tone	hands
🫱🏾‍🫲🏼	handshake: medium-dark skin tone, medium-light skin tone	hands
🫱🏾‍🫲🏽	handshake: medium-dark skin tone, medium skin tone	hands
🫱🏾‍🫲🏿	handshake: medium-dark skin tone, dark skin tone	hands
🫱🏿‍🫲🏻	handshake: dark skin tone, light skin tone	hands
🫱🏿‍🫲🏼	handshake: dark skin tone, medium-light skin tone	hands
🫱🏿‍🫲🏽	handshake: dark skin tone, medium skin tone	hands
🫱🏿‍🫲🏾	handshake: dark skin tone, medium-dark skin tone	hands
🙏	folded hands	hands
🙏🏻	folded hands: light skin tone	hands
🙏🏼	folded hands: medium-light skin tone	hands
🙏🏽	folded hands: medium skin tone	hands
🙏🏾	folded hands: medium-dark skin tone	hands
🙏🏿	folded hands: dark skin tone	hands
✍️	writing hand	hand-prop
✍🏻	writing hand: light skin tone	hand-prop
✍🏼	writing hand: medium-light skin tone	hand-prop
✍🏽	writing hand: medium skin tone	hand-prop
✍🏾	writing hand: medium-dark skin tone	hand-prop
✍🏿	writing hand: dark skin tone	hand-prop
💅	nail polish	hand-prop
💅🏻	nail polish: light skin tone	hand-prop
💅🏼	nail polish: medium-light skin tone	hand-prop
💅🏽	nail polish: medium skin tone	hand-prop
💅🏾	nail polish: medium-dark skin tone	hand-prop
💅🏿	nail polish: dark skin tone	hand-prop
🤳	selfie	hand-prop
🤳🏻	selfie: light skin tone	hand-prop
🤳🏼	selfie: medium-light skin tone	hand-prop
🤳🏽	selfie: medium skin tone	hand-prop
🤳🏾	selfie: medium-dark skin tone	hand-prop
🤳🏿	selfie: dark skin tone	hand-prop
💪	flexed biceps	body-parts
💪🏻	flexed biceps: light skin tone	body-parts
💪🏼	flexed biceps: medium-light skin tone	body-parts
💪🏽	flexed biceps: medium skin tone	body-parts
💪🏾	flexed biceps: medium-dark skin tone	body-parts
💪🏿	flexed biceps: dark skin tone	body-parts
🦾	mechanical arm	body-parts
🦿	mechanical leg	body-parts
🦵	leg	body-parts
🦵🏻	leg: light skin tone	body-parts
🦵🏼	leg: medium-light skin tone	body-parts
🦵🏽	leg: medium skin tone	body-parts
🦵🏾	leg: medium-dark skin tone	body-parts
🦵🏿	leg: dark skin tone	body-parts
🦶	foot	body-parts
🦶🏻	foot: light skin tone	body-parts
🦶🏼	foot: medium-light skin tone	body-parts
🦶🏽	foot: medium skin tone	body-parts
🦶🏾	foot: medium-dark skin tone	body-parts
🦶🏿	foot: dark skin tone	body-parts
👂	ear	body-parts
👂🏻	ear: light skin tone	body-parts
👂🏼	ear: medium-light skin tone	body-parts
👂🏽	ear: medium skin tone	body-parts
👂🏾	ear: medium-dark skin tone	body-parts
👂🏿	ear: dark skin tone	body-parts
🦻	ear with hearing aid	body-parts
🦻🏻	ear with hearing aid: light skin tone	body-parts
🦻🏼	ear with hearing aid: medium-light skin tone	body-parts
🦻🏽	ear with hearing aid: medium skin tone	body-parts
🦻🏾	ear with hearing aid: medium-dark skin tone	body-parts
🦻🏿	ear with hearing aid: dark skin tone	body-parts
👃	nose	body-parts
👃🏻	nose: light skin tone	body-parts
👃🏼	nose: medium-light skin tone	body-parts
👃🏽	nose: medium skin tone	body-parts
👃🏾	nose: medium-dark skin tone	body-parts
👃🏿	nose: dark skin tone	body-parts
🧠	brain	body-parts
🫀	anatomical heart	body-parts
🫁	lungs	body-parts
🦷	tooth	body-parts
🦴	bone	body-parts
👀	eyes	body-parts
👁️	eye	body-parts
👅	tongue	body-parts
👄	mouth	body-parts
🫦	biting lip	body-parts
👶	baby	person
👶🏻	baby: light skin tone	person
👶🏼	baby: medium-light skin tone	person
👶🏽	baby: medium skin tone	person
👶🏾	baby: medium-dark skin tone	person
👶🏿	baby: dark skin tone	person
🧒	child	person
🧒🏻	child: light skin tone	person
🧒🏼	child: medium-light skin tone	person
🧒🏽	child: medium skin tone	person
🧒🏾	child: medium-dark skin tone	person
🧒🏿	child: dark skin tone	person
👦	boy	person
👦🏻	boy: light skin tone	person
👦🏼	boy: medium-light skin tone	person
👦🏽	boy: medium skin tone	person
👦🏾	boy: medium-dark skin tone	person
👦🏿	boy: dark skin tone	person
👧	girl	person
👧🏻	girl: light skin tone	person
👧🏼	girl: medium-light skin tone	person
👧🏽	girl: medium skin tone	person
👧🏾	girl: medium-dark skin tone	person
👧🏿	girl: dark skin tone	person
🧑	person	person
🧑🏻	person: light skin tone	person
🧑🏼	person: medium-light skin tone	person
🧑🏽	person: medium skin tone	person
🧑🏾	person: medium-dark skin tone	person
🧑🏿	person: dark skin tone	person
👱	person: blond hair	person
👱🏻	person: light skin tone, blond hair	person
👱🏼	person: medium-light skin tone, blond hair	person
👱🏽	person: medium skin tone, blond hair	person
👱🏾	person: medium-dark skin tone, blond hair	person
👱🏿	person: dark skin tone, blond hair	person
👨	man	person
👨🏻	man: light skin tone	person
👨🏼	man: medium-light skin tone	person
👨🏽	man: medium skin tone	person
👨🏾	man: medium-dark skin tone	person
👨🏿	man: dark skin tone	person
🧔	person: beard	person
🧔🏻	person: light skin tone, beard	person
🧔🏼	person: medium-light skin tone, beard	person
🧔🏽	person: medium skin tone, beard	person
🧔🏾	person: medium-dark skin tone, beard	person
🧔🏿	person: dark skin tone, beard	person
🧔‍♂️	man: beard	person
🧔🏻‍♂️	man: light skin tone, beard	person
🧔🏼‍♂️	man: medium-light skin tone, beard	person
🧔🏽‍♂️	man: medium skin tone, beard	person
🧔🏾‍♂️	man: medium-dark skin tone, beard	person
🧔🏿‍♂️	man: dark skin tone, beard	person
🧔‍♀️	woman: beard	person
🧔🏻‍♀️	woman: light skin tone, beard	person
🧔🏼‍♀️	woman: medium-light skin tone, beard	person
🧔🏽‍♀️	woman: medium skin tone, beard	person
🧔🏾‍♀️	woman: medium-dark skin tone, beard	person
🧔🏿‍♀️	woman: dark skin tone, beard	person
👨‍🦰	man: red hair	person
👨🏻‍🦰	man: light skin tone, red hair	person
👨🏼‍🦰	man: medium-light skin tone, red hair	person
👨🏽‍🦰	man: medium skin tone, red hair	person
👨🏾‍🦰	man: medium-dark skin tone, red hair	person
👨🏿‍🦰	man: dark skin tone, red hair	person
👨‍🦱	man: curly hair	person
👨🏻‍🦱	man: light skin tone, curly hair	person
👨🏼‍🦱	man: medium-light skin tone, curly hair	person
👨🏽‍🦱	man: medium skin tone, curly hair	person
👨🏾‍🦱	man: medium-dark skin tone, curly hair	person
👨🏿‍🦱	man: dark skin tone, curly hair	person
👨‍🦳	man: white hair	person
👨🏻‍🦳	man: light skin tone, white hair	person
👨🏼‍🦳	man: medium-light skin tone, white hair	person
👨🏽‍🦳	man: medium skin tone, white hair	person
👨🏾‍🦳	man: medium-dark skin tone, white hair	person
👨🏿‍🦳	man: dark skin tone, white hair	person
👨‍🦲	man: bald	person
👨🏻‍🦲	man: light skin tone, bald	person
👨🏼‍🦲	man: medium-light skin tone, bald	person
👨🏽‍🦲	man: medium skin tone, bald	person
👨🏾‍🦲	man: medium-dark skin tone, bald	person
👨🏿‍🦲	man: dark skin tone, bald	person
👩	woman	person
👩🏻	woman: light skin tone	person
👩🏼	woman: medium-light skin tone	person
👩🏽	woman: medium skin tone	person
👩🏾	woman: medium-dark skin tone	person
👩🏿	woman: dark skin tone	person
👩‍🦰	woman: red hair	person
👩🏻‍🦰	woman: light skin tone, red hair	person
👩🏼‍🦰	woman: medium-light skin tone, red hair	person
👩🏽‍🦰	woman: medium skin tone, red hair	person
👩🏾‍🦰	woman: medium-dark skin tone, red hair	person
👩🏿‍🦰	woman: dark skin tone, red hair	person
🧑‍🦰	person: red hair	person
🧑🏻‍🦰	person: light skin tone, red hair	person
🧑🏼‍🦰	person: medium-light skin tone, red hair	person
🧑🏽‍🦰	person: medium skin tone, red hair	person
🧑🏾‍🦰	person: medium-dark skin tone, red hair	person
🧑🏿‍🦰	person: dark skin tone, red hair	person
👩‍🦱	woman: curly hair	person
👩🏻‍🦱	woman: light skin tone, curly hair	person
👩🏼‍🦱	woman: medium-light skin tone, curly hair	person
👩🏽‍🦱	woman: medium skin tone, curly hair	person
👩🏾‍🦱	woman: medium-dark skin tone, curly hair	person
👩🏿‍🦱	woman: dark skin tone, curly hair	person
🧑‍🦱	person: curly hair	person
🧑🏻‍🦱	person: light skin tone, curly hair	person
🧑🏼‍🦱	person: medium-light skin tone, curly hair	person
🧑🏽‍🦱	person: medium skin tone, curly hair	person
🧑🏾‍🦱	person: medium-dark skin tone, curly hair	person
🧑🏿‍🦱	person: dark skin tone, curly hair	person
👩‍🦳	woman: white hair	person
👩🏻‍🦳	woman: light skin tone, white hair	person
👩🏼‍🦳	woman: medium-light skin tone, white hair	person
👩🏽‍🦳	woman: medium skin tone, white hair	person
👩🏾‍🦳	woman: medium-dark skin tone, white hair	person
👩🏿‍🦳	woman: dark skin tone, white hair	person
🧑‍🦳	person: white hair	person
🧑🏻‍🦳	person: light skin tone, white hair	person
🧑🏼‍🦳	person: medium-light skin tone, white hair	person
🧑🏽‍🦳	person: medium skin tone, white hair	person
🧑🏾‍🦳	person: medium-dark skin tone, white hair	person
🧑🏿‍🦳	person: dark skin tone, white hair	person
👩‍🦲	woman: bald	person
👩🏻‍🦲	woman: light skin tone, bald	person
👩🏼‍🦲	woman: medium-light skin tone, bald	person
👩🏽‍🦲	woman: medium skin tone, bald	person
👩🏾‍🦲	woman: medium-dark skin tone, bald	person
👩🏿‍🦲	woman: dark skin tone, bald	person
🧑‍🦲	person: bald	person
🧑🏻‍🦲	person: light skin tone, bald	person
🧑🏼‍🦲	person: medium-light skin tone, bald	person
🧑🏽‍🦲	person: medium skin tone, bald	person
🧑🏾‍🦲	person: medium-dark skin tone, bald	person
🧑🏿‍🦲	person: dark skin tone, bald	person
👱‍♀️	woman: blond hair	person
👱🏻‍♀️	woman: light skin tone, blond hair	person
👱🏼‍♀️	woman: medium-light skin tone, blond hair	person
👱🏽‍♀️	woman: medium skin tone, blond hair	person
👱🏾‍♀️	woman: medium-dark skin tone, blond hair	person
👱🏿‍♀️	woman: dark skin tone, blond hair	person
👱‍♂️	man: blond hair	person
👱🏻‍♂️	man: light skin tone, blond hair	person
👱🏼‍♂️	man: medium-light skin tone, blond hair	person
👱🏽‍♂️	man: medium skin tone, blond hair	person
👱🏾‍♂️	man: medium-dark skin tone, blond hair	person
👱🏿‍♂️	man: dark skin tone, blond hair	person
🧓	older person	person
🧓🏻	older person: light skin tone	person
🧓🏼	older person: medium-light skin tone	person
🧓🏽	older person: medium skin tone	person
🧓🏾	older person: medium-dark skin tone	person
🧓🏿	older person: dark skin tone	person
👴	old man	person
👴🏻	old man: light skin tone	person
👴🏼	old man: medium-light skin tone	person
👴🏽	old man: medium skin tone	person
👴🏾	old man: medium-dark skin tone	person
👴🏿	old man: dark skin tone	person
👵	old woman	person
👵🏻	old woman: light skin tone	person
👵🏼	old woman: medium-light skin tone	person
👵🏽	old woman: medium skin tone	person
👵🏾	old woman: medium-dark skin tone	person
👵🏿	old woman: dark skin tone	person
🙍	person frowning	person-gesture
🙍🏻	person frowning: light skin tone	person-gesture
🙍🏼	person frowning: medium-light skin tone	person-gesture
🙍🏽	person frowning: medium skin tone	person-gesture
🙍🏾	person frowning: medium-dark skin tone	person-gesture
🙍🏿	person frowning: dark skin tone	person-gesture
🙍‍♂️	man frowning	person-gesture
🙍🏻‍♂️	man frowning: light skin tone	person-gesture
🙍🏼‍♂️	man frowning: medium-light skin tone	person-gesture
🙍🏽‍♂️	man frowning: medium skin tone	person-gesture
🙍🏾‍♂️	man frowning: medium-dark skin tone	person-gesture
🙍🏿‍♂️	man frowning: dark skin tone	person-gesture
🙍‍♀️	woman frowning	person-gesture
🙍🏻‍♀️	woman frowning: light skin tone	person-gesture
🙍🏼‍♀️	woman frowning: medium-light skin tone	person-gesture
🙍🏽‍♀️	woman frowning: medium skin tone	person-gesture
🙍🏾‍♀️	woman frowning: medium-dark skin tone	person-gesture
🙍🏿‍♀️	woman frowning: dark skin tone	person-gesture
🙎	person pouting	person-gesture
🙎🏻	person pouting: light skin tone	person-gesture
🙎🏼	person pouting: medium-light skin tone	person-gesture
🙎🏽	person pouting: medium skin tone	person-gesture
🙎🏾	person pouting: medium-dark skin tone	person-gesture
🙎🏿	person pouting: dark skin tone	person-gesture
🙎‍♂️	man pouting	person-gesture
🙎🏻‍♂️	man pouting: light skin tone	person-gesture
🙎🏼‍♂️	man pouting: medium-light skin tone	person-gesture
🙎🏽‍♂️	man pouting: medium skin tone	person-gesture
🙎🏾‍♂️	man pouting: medium-dark skin tone	person-gesture
🙎🏿‍♂️	man pouting: dark skin tone	person-gesture
🙎‍♀️	woman pouting	person-gesture
🙎🏻‍♀️	woman pouting: light skin tone	person-gesture
🙎🏼‍♀️	woman pouting: medium-light skin tone	person-gesture
🙎🏽‍♀️	woman pouting: medium skin tone	person-gesture
🙎🏾‍♀️	woman pouting: medium-dark skin tone	person-gesture
🙎🏿‍♀️	woman pouting: dark skin tone	person-gesture
🙅	person gesturing NO	person-gesture
🙅🏻	person gesturing NO: light skin tone	person-gesture
🙅🏼	person gesturing NO: medium-light skin tone	person-gesture
🙅🏽	person gesturing NO: medium skin tone	person-gesture
🙅🏾	person gesturing NO: medium-dark skin tone	person-gesture
🙅🏿	person gesturing NO: dark skin tone	person-gesture
🙅‍♂️	man gesturing NO	person-gesture
🙅🏻‍♂️	man gesturing NO: light skin tone	person-gesture
🙅🏼‍♂️	man gesturing NO: medium-light skin tone	person-gesture
🙅🏽‍♂️	man gesturing NO: medium skin tone	person-gesture
🙅🏾‍♂️	man gesturing NO: medium-dark skin tone	person-gesture
🙅🏿‍♂️	man gesturing NO: dark skin tone	person-gesture
🙅‍♀️	woman gesturing NO	person-gesture
🙅🏻‍♀️	woman gesturing NO: light skin tone	person-gesture
🙅🏼‍♀️	woman gesturing NO: medium-light skin tone	person-gesture
🙅🏽‍♀️	woman gesturing NO: medium skin tone	person-gesture
🙅🏾‍♀️	woman gesturing NO: medium-dark skin tone	person-gesture
🙅🏿‍♀️	woman gesturing NO: dark skin tone	person-gesture
🙆	person gesturing OK	person-gesture
🙆🏻	person gesturing OK: light skin tone	person-gesture
🙆🏼	person gesturing OK: medium-light skin tone	person-gesture
🙆🏽	person gesturing OK: medium skin tone	person-gesture
🙆🏾	person gesturing OK: medium-dark skin tone	person-gesture
🙆🏿	person gesturing OK: dark skin tone	person-gesture
🙆‍♂️	man gesturing OK	person-gesture
🙆🏻‍♂️	man gesturing OK: light skin tone	person-gesture
🙆🏼‍♂️	man gesturing OK: medium-light skin tone	person-gesture
🙆🏽‍♂️	man gesturing OK: medium skin tone	person-gesture
🙆🏾‍♂️	man gesturing OK: medium-dark skin tone	person-gesture
🙆🏿‍♂️	man gesturing OK: dark skin tone	person-gesture
🙆‍♀️	woman gesturing OK	person-gesture
🙆🏻‍♀️	woman gesturing OK: light skin tone	person-gesture
🙆🏼‍♀️	woman gesturing OK: medium-light skin tone	person-gesture
🙆🏽‍♀️	woman gesturing OK: medium skin tone	person-gesture
🙆🏾‍♀️	woman gesturing OK: medium-dark skin tone	person-gesture
🙆🏿‍♀️	woman gesturing OK: dark skin tone	person-gesture
💁	person tipping hand	person-gesture
💁🏻	person tipping hand: light skin tone	person-gesture
💁🏼	person tipping hand: medium-light skin tone	person-gesture
💁🏽	person tipping hand: medium skin tone	person-gesture
💁🏾	person tipping hand: medium-dark skin tone	person-gesture
💁🏿	person tipping hand: dark skin tone	person-gesture
💁‍♂️	man tipping hand	person-gesture
💁🏻‍♂️	man tipping hand: light skin tone	person-gesture
💁🏼‍♂️	man tipping hand: medium-light skin tone	person-gesture
💁🏽‍♂️	man tipping hand: medium skin tone	person-gesture
💁🏾‍♂️	man tipping hand: medium-dark skin tone	person-gesture
💁🏿‍♂️	man tipping hand: dark skin tone	person-gesture
💁‍♀️	woman tipping hand	person-gesture
💁🏻‍♀️	woman tipping hand: light skin tone	person-gesture
💁🏼‍♀️	woman tipping hand: medium-light skin tone	person-gesture
💁🏽‍♀️	woman tipping hand: medium skin tone	person-gesture
💁🏾‍♀️	woman tipping hand: medium-dark skin tone	person-gesture
💁🏿‍♀️	woman tipping hand: dark skin tone	person-gesture
🙋	person raising hand	person-gesture
🙋🏻	person raising hand: light skin tone	person-gesture
🙋🏼	person raising hand: medium-light skin tone	person-gesture
🙋🏽	person raising hand: medium skin tone	person-gesture
🙋🏾	person raising hand: medium-dark skin tone	person-gesture
🙋🏿	person raising hand: dark skin tone	person-gesture
🙋‍♂️	man raising hand	person-gesture
🙋🏻‍♂️	man raising hand: light skin tone	person-gesture
🙋🏼‍♂️	man raising hand: medium-light skin tone	person-gesture
🙋🏽‍♂️	man raising hand: medium skin tone	person-gesture
🙋🏾‍♂️	man raising hand: medium-dark skin tone	person-gesture
🙋🏿‍♂️	man raising hand: dark skin tone	person-gesture
🙋‍♀️	woman raising hand	person-gesture
🙋🏻‍♀️	woman raising hand: light skin tone	person-gesture
🙋🏼‍♀️	woman raising hand: medium-light skin tone	person-gesture
🙋🏽‍♀️	woman raising hand: medium skin tone	person-gesture
🙋🏾‍♀️	woman raising hand: medium-dark skin tone	person-gesture
🙋🏿‍♀️	woman raising hand: dark skin tone	person-gesture
🧏	deaf person	person-gesture
🧏🏻	deaf person: light skin tone	person-gesture
🧏🏼	deaf person: medium-light skin tone	person-gesture
🧏🏽	deaf person: medium skin tone	person-gesture
🧏🏾	deaf person: medium-dark skin tone	person-gesture
🧏🏿	deaf person: dark skin tone	person-gesture
🧏‍♂️	deaf man	person-gesture
🧏🏻‍♂️	deaf man: light skin tone	person-gesture
🧏🏼‍♂️	deaf man: medium-light skin tone	person-gesture
🧏🏽‍♂️	deaf man: medium skin tone	person-gesture
🧏🏾‍♂️	deaf man: medium-dark skin tone	person-gesture
🧏🏿‍♂️	deaf man: dark skin tone	person-gesture
🧏‍♀️	deaf woman	person-gesture
🧏🏻‍♀️	deaf woman: light skin tone	person-gesture
🧏🏼‍♀️	deaf woman: medium-light skin tone	person-gesture
🧏🏽‍♀️	deaf woman: medium skin tone	person-gesture
🧏🏾‍♀️	deaf woman: medium-dark skin tone	person-gesture
🧏🏿‍♀️	deaf woman: dark skin tone	person-gesture
🙇	person bowing	person-gesture
🙇🏻	person bowing: light skin tone	person-gesture
🙇🏼	person bowing: medium-light skin tone	person-gesture
🙇🏽	person bowing: medium skin tone	person-gesture
🙇🏾	person bowing: medium-dark skin tone	person-gesture
🙇🏿	person bowing: dark skin tone	person-gesture
🙇‍♂️	man bowing	person-gesture
🙇🏻‍♂️	man bowing: light skin tone	person-gesture
🙇🏼‍♂️	man bowing: medium-light skin tone	person-gesture
🙇🏽‍♂️	man bowing: medium skin tone	person-gesture
🙇🏾‍♂️	man bowing: medium-dark skin tone	person-gesture
🙇🏿‍♂️	man bowing: dark skin tone	person-gesture
🙇‍♀️	woman bowing	person-gesture
🙇🏻‍♀️	woman bowing: light skin tone	person-gesture
🙇🏼‍♀️	woman bowing: medium-light skin tone	person-gesture
🙇🏽‍♀️	woman bowing: medium skin tone	person-gesture
🙇🏾‍♀️	woman bowing: medium-dark skin tone	person-gesture
🙇🏿‍♀️	woman bowing: dark skin tone	person-gesture
🤦	person facepalming	person-gesture
🤦🏻	person facepalming: light skin tone	person-gesture
🤦🏼	person facepalming: medium-light skin tone	person-gesture
🤦🏽	person facepalming: medium skin tone	person-gesture
🤦🏾	person facepalming: medium-dark skin tone	person-gesture
🤦🏿	person facepalming: dark skin tone	person-gesture
🤦‍♂️	man facepalming	person-gesture
🤦🏻‍♂️	man facepalming: light skin tone	person-gesture
🤦🏼‍♂️	man facepalming: medium-light skin tone	person-gesture
🤦🏽‍♂️	man facepalming: medium skin tone	person-gesture
🤦🏾‍♂️	man facepalming: medium-dark skin tone	person-gesture
🤦🏿‍♂️	man facepalming: dark skin tone	person-gesture
🤦‍♀️	woman facepalming	person-gesture
🤦🏻‍♀️	woman facepalming: light skin tone	person-gesture
🤦🏼‍♀️	woman facepalming: medium-light skin tone	person-gesture
🤦🏽‍♀️	woman facepalming: medium skin tone	person-gesture
🤦🏾‍♀️	woman facepalming: medium-dark skin tone	person-gesture
🤦🏿‍♀️	woman facepalming: dark skin tone	person-gesture
🤷	person shrugging	person-gesture
🤷🏻	person shrugging: light skin tone	person-gesture
🤷🏼	person shrugging: medium-light skin tone	person-gesture
🤷🏽	person shrugging: medium skin tone	person-gesture
🤷🏾	person shrugging: medium-dark skin tone	person-gesture
🤷🏿	person shrugging: dark skin tone	person-gesture
🤷‍♂️	man shrugging	person-gesture
🤷🏻‍♂️	man shrugging: light skin tone	person-gesture
🤷🏼‍♂️	man shrugging: medium-light skin tone	person-gesture
🤷🏽‍♂️	man shrugging: medium skin tone	person-gesture
🤷🏾‍♂️	man shrugging: medium-dark skin tone	person-gesture
🤷🏿‍♂️	man shrugging: dark skin tone	person-gesture
🤷‍♀️	woman shrugging	person-gesture
🤷🏻‍♀️	woman shrugging: light skin tone	person-gesture
🤷🏼‍♀️	woman shrugging: medium-light skin tone	person-gesture
🤷🏽‍♀️	woman shrugging: medium skin tone	person-gesture
🤷🏾‍♀️	woman shrugging: medium-dark skin tone	person-gesture
🤷🏿‍♀️	woman shrugging: dark skin tone	person-gesture
🧑‍⚕️	health worker	person-role
🧑🏻‍⚕️	health worker: light skin tone	person-role
🧑🏼‍⚕️	health worker: medium-light skin tone	person-role
🧑🏽‍⚕️	health worker: medium skin tone	person-role
🧑🏾‍⚕️	health worker: medium-dark skin tone	person-role
🧑🏿‍⚕️	health worker: dark skin tone	person-role
👨‍⚕️	man health worker	person-role
👨🏻‍⚕️	man health worker: light skin tone	person-role
👨🏼‍⚕️	man health worker: medium-light skin tone	person-role
👨🏽‍⚕️	man health worker: medium skin tone	person-role
👨🏾‍⚕️	man health worker: medium-dark skin tone	person-role
👨🏿‍⚕️	man health worker: dark skin tone	person-role
👩‍⚕️	woman health worker	person-role
👩🏻‍⚕️	woman health worker: light skin tone	person-role
👩🏼‍⚕️	woman health worker: medium-light skin tone	person-role
👩🏽‍⚕️	woman health worker: medium skin tone	person-role
👩🏾‍⚕️	woman health worker: medium-dark skin tone	person-role
👩🏿‍⚕️	woman health worker: dark skin tone	person-role
🧑‍🎓	student	person-role
🧑🏻‍🎓	student: light skin tone	person-role
🧑🏼‍🎓	student: medium-light skin tone	person-role
🧑🏽‍🎓	student: medium skin tone	person-role
🧑🏾‍🎓	student: medium-dark skin tone	person-role
🧑🏿‍🎓	student: dark skin tone	person-role
👨‍🎓	man student	person-role
👨🏻‍🎓	man student: light skin tone	person-role
👨🏼‍🎓	man student: medium-light skin tone	person-role
👨🏽‍🎓	man student: medium skin tone	person-role
👨🏾‍🎓	man student: medium-dark skin tone	person-role
👨🏿‍🎓	man student: dark skin tone	person-role
👩‍🎓	woman student	person-role
👩🏻‍🎓	woman student: light skin tone	person-role
👩🏼‍🎓	woman student: medium-light skin tone	person-role
👩🏽‍🎓	woman student: medium skin tone	person-role
👩🏾‍🎓	woman student: medium-dark skin tone	person-role
👩🏿‍🎓	woman student: dark skin tone	person-role
🧑‍🏫	teacher	person-role
🧑🏻‍🏫	teacher: light skin tone	person-role
🧑🏼‍🏫	teacher: medium-light skin tone	person-role
🧑🏽‍🏫	teacher: medium skin tone	person-role
🧑🏾‍🏫	teacher: medium-dark skin tone	person-role
🧑🏿‍🏫	teacher: dark skin tone	person-role
👨‍🏫	man teacher	person-role
👨🏻‍🏫	man teacher: light skin tone	person-role
👨🏼‍🏫	man teacher: medium-light skin tone	person-role
👨🏽‍🏫	man teacher: medium skin tone	person-role
👨🏾‍🏫	man teacher: medium-dark skin tone	person-role
👨🏿‍🏫	man teacher: dark skin tone	person-role
👩‍🏫	woman teacher	person-role
👩🏻‍🏫	woman teacher: light skin tone	person-role
👩🏼‍🏫	woman teacher: medium-light skin tone	person-role
👩🏽‍🏫	woman teacher: medium skin tone	person-role
👩🏾‍🏫	woman teacher: medium-dark skin tone	person-role
👩🏿‍🏫	woman teacher: dark skin tone	person-role
🧑‍⚖️	judge	person-role
🧑🏻‍⚖️	judge: light skin tone	person-role
🧑🏼‍⚖️	judge: medium-light skin tone	person-role
🧑🏽‍⚖️	judge: medium skin tone	person-role
🧑🏾‍⚖️	judge: medium-dark skin tone	person-role
🧑🏿‍⚖️	judge: dark skin tone	person-role
👨‍⚖️	man judge	person-role
👨🏻‍⚖️	man judge: light skin tone	person-role
👨🏼‍⚖️	man judge: medium-light skin tone	person-role
👨🏽‍⚖️	man judge: medium skin tone	person-role
👨🏾‍⚖️	man judge: medium-dark skin tone	person-role
👨🏿‍⚖️	man judge: dark skin tone	person-role
👩‍⚖️	woman judge	person-role
👩🏻‍⚖️	woman judge: light skin tone	person-role
👩🏼‍⚖️	woman judge: medium-light skin tone	person-role
👩🏽‍⚖️	woman judge: medium skin tone	person-role
👩🏾‍⚖️	woman judge: medium-dark skin tone	person-role
👩🏿‍⚖️	woman judge: dark skin tone	person-role
🧑‍🌾	farmer	person-role
🧑🏻‍🌾	farmer: light skin tone	person-role
🧑🏼‍🌾	farmer: medium-light skin tone	person-role
🧑🏽‍🌾	farmer: medium skin tone	person-role
🧑🏾‍🌾	farmer: medium-dark skin tone	person-role
🧑🏿‍🌾	farmer: dark skin tone	person-role
👨‍🌾	man farmer	person-role
👨🏻‍🌾	man farmer: light skin tone	person-role
👨🏼‍🌾	man farmer: medium-light skin tone	person-role
👨🏽‍🌾	man farmer: medium skin tone	person-role
👨🏾‍🌾	man farmer: medium-dark skin tone	person-role
👨🏿‍🌾	man farmer: dark skin tone	person-role
👩‍🌾	woman farmer	person-role
👩🏻‍🌾	woman farmer: light skin tone	person-role
👩🏼‍🌾	woman farmer: medium-light skin tone	person-role
👩🏽‍🌾	woman farmer: medium skin tone	person-role
👩🏾‍🌾	woman farmer: medium-dark skin tone	person-role
👩🏿‍🌾	woman farmer: dark skin tone	person-role
🧑‍🍳	cook	person-role
🧑🏻‍🍳	cook: light skin tone	person-role
🧑🏼‍🍳	cook: medium-light skin tone	person-role
🧑🏽‍🍳	cook: medium skin tone	person-role
🧑🏾‍🍳	cook: medium-dark skin tone	person-role
🧑🏿‍🍳	cook: dark skin tone	person-role
👨‍🍳	man cook	person-role
👨🏻‍🍳	man cook: light skin tone	person-role
👨🏼‍🍳	man cook: medium-light skin tone	person-role
👨🏽‍🍳	man cook: medium skin tone	person-role
👨🏾‍🍳	man cook: medium-dark skin tone	person-role
👨🏿‍🍳	man cook: dark skin tone	person-role
👩‍🍳	woman cook	person-role
👩🏻‍🍳	woman cook: light skin tone	person-role
👩🏼‍🍳	woman cook: medium-light skin tone	person-role
👩🏽‍🍳	woman cook: medium skin tone	person-role
👩🏾‍🍳	woman cook: medium-dark skin tone	person-role
👩🏿‍🍳	woman cook: dark skin tone	person-role
🧑‍🔧	mechanic	person-role
🧑🏻‍🔧	mechanic: light skin tone	person-role
🧑🏼‍🔧	mechanic: medium-light skin tone	person-role
🧑🏽‍🔧	mechanic: medium skin tone	person-role
🧑🏾‍🔧	mechanic: medium-dark skin tone	person-role
🧑🏿‍🔧	mechanic: dark skin tone	person-role
👨‍🔧	man mechanic	person-role
👨🏻‍🔧	man mechanic: light skin tone	person-role
👨🏼‍🔧	man mechanic: medium-light skin tone	person-role
👨🏽‍🔧	man mechanic: medium skin tone	person-role
👨🏾‍🔧	man mechanic: medium-dark skin tone	person-role
👨🏿‍🔧	man mechanic: dark skin tone	person-role
👩‍🔧	woman mechanic	person-role
👩🏻‍🔧	woman mechanic: light skin tone	person-role
👩🏼‍🔧	woman mechanic: medium-light skin tone	person-role
👩🏽‍🔧	woman mechanic: medium skin tone	person-role
👩🏾‍🔧	woman mechanic: medium-dark skin tone	person-role
👩🏿‍🔧	woman mechanic: dark skin tone	person-role
🧑‍🏭	factory worker	person-role
🧑🏻‍🏭	factory worker: light skin tone	person-role
🧑🏼‍🏭	factory worker: medium-light skin tone	person-role
🧑🏽‍🏭	factory worker: medium skin tone	person-role
🧑🏾‍🏭	factory worker: medium-dark skin tone	person-role
🧑🏿‍🏭	factory worker: dark skin tone	person-role
👨‍🏭	man factory worker	person-role
👨🏻‍🏭	man factory worker: light skin tone	person-role
👨🏼‍🏭	man factory worker: medium-light skin tone	person-role
👨🏽‍🏭	man factory worker: medium skin tone	person-role
👨🏾‍🏭	man factory worker: medium-dark skin tone	person-role
👨🏿‍🏭	man factory worker: dark skin tone	person-role
👩‍🏭	woman factory worker	person-role
👩🏻‍🏭	woman factory worker: light skin tone	person-role
👩🏼‍🏭	woman factory worker: medium-light skin tone	person-role
👩🏽‍🏭	woman factory worker: medium skin tone	person-role
👩🏾‍🏭	woman factory worker: medium-dark skin tone	person-role
👩🏿‍🏭	woman factory worker: dark skin tone	person-role
🧑‍💼	office worker	person-role
🧑🏻‍💼	office worker: light skin tone	person-role
🧑🏼‍💼	office worker: medium-light skin tone	person-role
🧑🏽‍💼	office worker: medium skin tone	person-role
🧑🏾‍💼	office worker: medium-dark skin tone	person-role
🧑🏿‍💼	office worker: dark skin tone	person-role
👨‍💼	man office worker	person-role
👨🏻‍💼	man office worker: light skin tone	person-role
👨🏼‍💼	man office worker: medium-light skin tone	person-role
👨🏽‍💼	man office worker: medium skin tone	person-role
👨🏾‍💼	man office worker: medium-dark skin tone	person-role
👨🏿‍💼	man office worker: dark skin tone	person-role
👩‍💼	woman office worker	person-role
👩🏻‍💼	woman office worker: light skin tone	person-role
👩🏼‍💼	woman office worker: medium-light skin tone	person-role
👩🏽‍💼	woman office worker: medium skin tone	person-role
👩🏾‍💼	woman office worker: medium-dark skin tone	person-role
👩🏿‍💼	woman office worker: dark skin tone	person-role
🧑‍🔬	scientist	person-role
🧑🏻‍🔬	scientist: light skin tone	person-role
🧑🏼‍🔬	scientist: medium-light skin tone	person-role
🧑🏽‍🔬	scientist: medium skin tone	person-role
🧑🏾‍🔬	scientist: medium-dark skin tone	person-role
🧑🏿‍🔬	scientist: dark skin tone	person-role
👨‍🔬	man scientist	person-role
👨🏻‍🔬	man scientist: light skin tone	person-role
👨🏼‍🔬	man scientist: medium-light skin tone	person-role
👨🏽‍🔬	man scientist: medium skin tone	person-role
👨🏾‍🔬	man scientist: medium-dark skin tone	person-role
👨🏿‍🔬	man scientist: dark skin tone	person-role
👩‍🔬	woman scientist	person-role
👩🏻‍🔬	woman scientist: light skin tone	person-role
👩🏼‍🔬	woman scientist: medium-light skin tone	person-role
👩🏽‍🔬	woman scientist: medium skin tone	person-role
👩🏾‍🔬	woman scientist: medium-dark skin tone	person-role
👩🏿‍🔬	woman scientist: dark skin tone	person-role
🧑‍💻	technologist	person-role
🧑🏻‍💻	technologist: light skin tone	person-role
🧑🏼‍💻	technologist: medium-light skin tone	person-role
🧑🏽‍💻	technologist: medium skin tone	person-role
🧑🏾‍💻	technologist: medium-dark skin tone	person-role
🧑🏿‍💻	technologist: dark skin tone	person-role
👨‍💻	man technologist	person-role
👨🏻‍💻	man technologist: light skin tone	person-role
👨🏼‍💻	man technologist: medium-light skin tone	person-role
👨🏽‍💻	man technologist: medium skin tone	person-role
👨🏾‍💻	man technologist: medium-dark skin tone	person-role
👨🏿‍💻	man technologist: dark skin tone	person-role
👩‍💻	woman technologist	person-role
👩🏻‍💻	woman technologist: light skin tone	person-role
👩🏼‍💻	woman technologist: medium-light skin tone	person-role
👩🏽‍💻	woman technologist: medium skin tone	person-role
👩🏾‍💻	woman technologist: medium-dark skin tone	person-role
👩🏿‍💻	woman technologist: dark skin tone	person-role
🧑‍🎤	singer	person-role
🧑🏻‍🎤	singer: light skin tone	person-role
🧑🏼‍🎤	singer: medium-light skin tone	person-role
🧑🏽‍🎤	singer: medium skin tone	person-role
🧑🏾‍🎤	singer: medium-dark skin tone	person-role
🧑🏿‍🎤	singer: dark skin tone	person-role
👨‍🎤	man singer	person-role
👨🏻‍🎤	man singer: light skin tone	person-role
👨🏼‍🎤	man singer: medium-light skin tone	person-role
👨🏽‍🎤	man singer: medium skin tone	person-role
👨🏾‍🎤	man singer: medium-dark skin tone	person-role
👨🏿‍🎤	man singer: dark skin tone	person-role
👩‍🎤	woman singer	person-role
👩🏻‍🎤	woman singer: light skin tone	person-role
👩🏼‍🎤	woman singer: medium-light skin tone	person-role
👩🏽‍🎤	woman singer: medium skin tone	person-role
👩🏾‍🎤	woman singer: medium-dark skin tone	person-role
👩🏿‍🎤	woman singer: dark skin tone	person-role
🧑‍🎨	artist	person-role
🧑🏻‍🎨	artist: light skin tone	person-role
🧑🏼‍🎨	artist: medium-light skin tone	person-role
🧑🏽‍🎨	artist: medium skin tone	person-role
🧑🏾‍🎨	artist: medium-dark skin tone	person-role
🧑🏿‍🎨	artist: dark skin tone	person-role
👨‍🎨	man artist	person-role
👨🏻‍🎨	man artist: light skin tone	person-role
👨🏼‍🎨	man artist: medium-light skin tone	person-role
👨🏽‍🎨	man artist: medium skin tone	person-role
👨🏾‍🎨	man artist: medium-dark skin tone	person-role
👨🏿‍🎨	man artist: dark skin tone	person-role
👩‍🎨	woman artist	person-role
👩🏻‍🎨	woman artist: light skin tone	person-role
👩🏼‍🎨	woman artist: medium-light skin tone	person-role
👩🏽‍🎨	woman artist: medium skin tone	person-role
👩🏾‍🎨	woman artist: medium-dark skin tone	person-role
👩🏿‍🎨	woman artist: dark skin tone	person-role
🧑‍✈️	pilot	person-role
🧑🏻‍✈️	pilot: light skin tone	person-role
🧑🏼‍✈️	pilot: medium-light skin tone	person-role
🧑🏽‍✈️	pilot: medium skin tone	person-role
🧑🏾‍✈️	pilot: medium-dark skin tone	person-role
🧑🏿‍✈️	pilot: dark skin tone	person-role
👨‍✈️	man pilot	person-role
👨🏻‍✈️	man pilot: light skin tone	person-role
👨🏼‍✈️	man pilot: medium-light skin tone	person-role
👨🏽‍✈️	man pilot: medium skin tone	person-role
👨🏾‍✈️	man pilot: medium-dark skin tone	person-role
👨🏿‍✈️	man pilot: dark skin tone	person-role
👩‍✈️	woman pilot	person-role
👩🏻‍✈️	woman pilot: light skin tone	person-role
👩🏼‍✈️	woman pilot: medium-light skin tone	person-role
👩🏽‍✈️	woman pilot: medium skin tone	person-role
👩🏾‍✈️	woman pilot: medium-dark skin tone	person-role
👩🏿‍✈️	woman pilot: dark skin tone	person-role
🧑‍🚀	astronaut	person-role
🧑🏻‍🚀	astronaut: light skin tone	person-role
🧑🏼‍🚀	astronaut: medium-light skin tone	person-role
🧑🏽‍🚀	astronaut: medium skin tone	person-role
🧑🏾‍🚀	astronaut: medium-dark skin tone	person-role
🧑🏿‍🚀	astronaut: dark skin tone	person-role
👨‍🚀	man astronaut	person-role
👨🏻‍🚀	man astronaut: light skin tone	person-role
👨🏼‍🚀	man astronaut: medium-light skin tone	person-role
👨🏽‍🚀	man astronaut: medium skin tone	person-role
👨🏾‍🚀	man astronaut: medium-dark skin tone	person-role
👨🏿‍🚀	man astronaut: dark skin tone	person-role
👩‍🚀	woman astronaut	person-role
👩🏻‍🚀	woman astronaut: light skin tone	person-role
👩🏼‍🚀	woman astronaut: medium-light skin tone	person-role
👩🏽‍🚀	woman astronaut: medium skin tone	person-role
👩🏾‍🚀	woman astronaut: medium-dark skin tone	person-role
👩🏿‍🚀	woman astronaut: dark skin tone	person-role
🧑‍🚒	firefighter	person-role
🧑🏻‍🚒	firefighter: light skin tone	person-role
🧑🏼‍🚒	firefighter: medium-light skin tone	person-role
🧑🏽‍🚒	firefighter: medium skin tone	person-role
🧑🏾‍🚒	firefighter: medium-dark skin tone	person-role
🧑🏿‍🚒	firefighter: dark skin tone	person-role
👨‍🚒	man firefighter	person-role
👨🏻‍🚒	man firefighter: light skin tone	person-role
👨🏼‍🚒	man firefighter: medium-light skin tone	person-role
👨🏽‍🚒	man firefighter: medium skin tone	person-role
👨🏾‍🚒	man firefighter: medium-dark skin tone	person-role
👨🏿‍🚒	man firefighter: dark skin tone	person-role
👩‍🚒	woman firefighter	person-role
👩🏻‍🚒	woman firefighter: light skin tone	person-role
👩🏼‍🚒	woman firefighter: medium-light skin tone	person-role
👩🏽‍🚒	woman firefighter: medium skin tone	person-role
👩🏾‍🚒	woman firefighter: medium-dark skin tone	person-role
👩🏿‍🚒	woman firefighter: dark skin tone	person-role
👮	police officer	person-role
👮🏻	police officer: light skin tone	person-role
👮🏼	police officer: medium-light skin tone	person-role
👮🏽	police officer: medium skin tone	person-role
👮🏾	police officer: medium-dark skin tone	person-role
👮🏿	police officer: dark skin tone	person-role
👮‍♂️	man police officer	person-role
👮🏻‍♂️	man police officer: light skin tone	person-role
👮🏼‍♂️	man police officer: medium-light skin tone	person-role
👮🏽‍♂️	man police officer: medium skin tone	person-role
👮🏾‍♂️	man police officer: medium-dark skin tone	person-role
👮🏿‍♂️	man police officer: dark skin tone	person-role
👮‍♀️	woman police officer	person-role
👮🏻‍♀️	woman police officer: light skin tone	person-role
👮🏼‍♀️	woman police officer: medium-light skin tone	person-role
👮🏽‍♀️	woman police officer: medium skin tone	person-role
👮🏾‍♀️	woman police officer: medium-dark skin tone	person-role
👮🏿‍♀️	woman police officer: dark skin tone	person-role
🕵️	detective	person-role
🕵🏻	detective: light skin tone	person-role
🕵🏼	detective: medium-light skin tone	person-role
🕵🏽	detective: medium skin tone	person-role
🕵🏾	detective: medium-dark skin tone	person-role
🕵🏿	detective: dark skin tone	person-role
🕵️‍♂️	man detective	person-role
🕵🏻‍♂️	man detective: light skin tone	person-role
🕵🏼‍♂️	man detective: medium-light skin tone	person-role
🕵🏽‍♂️	man detective: medium skin tone	person-role
🕵🏾‍♂️	man detective: medium-dark skin tone	person-role
🕵🏿‍♂️	man detective: dark skin tone	person-role
🕵️‍♀️	woman detective	person-role
🕵🏻‍♀️	woman detective: light skin tone	person-role
🕵🏼‍♀️	woman detective: medium-light skin tone	person-role
🕵🏽‍♀️	woman detective: medium skin tone	person-role
🕵🏾‍♀️	woman detective: medium-dark skin tone	person-role
🕵🏿‍♀️	woman detective: dark skin tone	person-role
💂	guard	person-role
💂🏻	guard: light skin tone	person-role
💂🏼	guard: medium-light skin tone	person-role
💂🏽	guard: medium skin tone	person-role
💂🏾	guard: medium-dark skin tone	person-role
💂🏿	guard: dark skin tone	person-role
💂‍♂️	man guard	person-role
💂🏻‍♂️	man guard: light skin tone	person-role
💂🏼‍♂️	man guard: medium-light skin tone	person-role
💂🏽‍♂️	man guard: medium skin tone	person-role
💂🏾‍♂️	man guard: medium-dark skin tone	person-role
💂🏿‍♂️	man guard: dark skin tone	person-role
💂‍♀️	woman guard	person-role
💂🏻‍♀️	woman guard: light skin tone	person-role
💂🏼‍♀️	woman guard: medium-light skin tone	person-role
💂🏽‍♀️	woman guard: medium skin tone	person-role
💂🏾‍♀️	woman guard: medium-dark skin tone	person-role
💂🏿‍♀️	woman guard: dark skin tone	person-role
🥷	ninja	person-role
🥷🏻	ninja: light skin tone	person-role
🥷🏼	ninja: medium-light skin tone	person-role
🥷🏽	ninja: medium skin tone	person-role
🥷🏾	ninja: medium-dark skin tone	person-role
🥷🏿	ninja: dark skin tone	person-role
👷	construction worker	person-role
👷🏻	construction worker: light skin tone	person-role
👷🏼	construction worker: medium-light skin tone	person-role
👷🏽	construction worker: medium skin tone	person-role
👷🏾	construction worker: medium-dark skin tone	person-role
👷🏿	construction worker: dark skin tone	person-role
👷‍♂️	man construction worker	person-role
👷🏻‍♂️	man construction worker: light skin tone	person-role
👷🏼‍♂️	man construction worker: medium-light skin tone	person-role
👷🏽‍♂️	man construction worker: medium skin tone	person-role
👷🏾‍♂️	man construction worker: medium-dark skin tone	person-role
👷🏿‍♂️	man construction worker: dark skin tone	person-role
👷‍♀️	woman construction worker	person-role
👷🏻‍♀️	woman construction worker: light skin tone	person-role
👷🏼‍♀️	woman construction worker: medium-light skin tone	person-role
👷🏽‍♀️	woman construction worker: medium skin tone	person-role
👷🏾‍♀️	woman construction worker: medium-dark skin tone	person-role
👷🏿‍♀️	woman construction worker: dark skin tone	person-role
🫅	person with crown	person-role
🫅🏻	person with crown: light skin tone	person-role
🫅🏼	person with crown: medium-light skin tone	person-role
🫅🏽	person with crown: medium skin tone	person-role
🫅🏾	person with crown: medium-dark skin tone	person-role
🫅🏿	person with crown: dark skin tone	person-role
🤴	prince	person-role
🤴🏻	prince: light skin tone	person-role
🤴🏼	prince: medium-light skin tone	person-role
🤴🏽	prince: medium skin tone	person-role
🤴🏾	prince: medium-dark skin tone	person-role
🤴🏿	prince: dark skin tone	person-role
👸	princess	person-role
👸🏻	princess: light skin tone	person-role
👸🏼	princess: medium-light skin tone	person-role
👸🏽	princess: medium skin tone	person-role
👸🏾	princess: medium-dark skin tone	person-role
👸🏿	princess: dark skin tone	person-role
👳	person wearing turban	person-role
👳🏻	person wearing turban: light skin tone	person-role
👳🏼	person wearing turban: medium-light skin tone	person-role
👳🏽	person wearing turban: medium skin tone	person-role
👳🏾	person wearing turban: medium-dark skin tone	person-role
👳🏿	person wearing turban: dark skin tone	person-role
👳‍♂️	man wearing turban	person-role
👳🏻‍♂️	man wearing turban: light skin tone	person-role
👳🏼‍♂️	man wearing turban: medium-light skin tone	person-role
👳🏽‍♂️	man wearing turban: medium skin tone	person-role
👳🏾‍♂️	man wearing turban: medium-dark skin tone	person-role
👳🏿‍♂️	man wearing turban: dark skin tone	person-role
👳‍♀️	woman wearing turban	person-role
👳🏻‍♀️	woman wearing turban: light skin tone	person-role
👳🏼‍♀️	woman wearing turban: medium-light skin tone	person-role
👳🏽‍♀️	woman wearing turban: medium skin tone	person-role
👳🏾‍♀️	woman wearing turban: medium-dark skin tone	person-role
👳🏿‍♀️	woman wearing turban: dark skin tone	person-role
👲	person with skullcap	person-role
👲🏻	person with skullcap: light skin tone	person-role
👲🏼	person with skullcap: medium-light skin tone	person-role
👲🏽	person with skullcap: medium skin tone	person-role
👲🏾	person with skullcap: medium-dark skin tone	person-role
👲🏿	person with skullcap: dark skin tone	person-role
🧕	woman with headscarf	person-role
🧕🏻	woman with headscarf: light skin tone	person-role
🧕🏼	woman with headscarf: medium-light skin tone	person-role
🧕🏽	woman with headscarf: medium skin tone	person-role
🧕🏾	woman with headscarf: medium-dark skin tone	person-role
🧕🏿	woman with headscarf: dark skin tone	person-role
🤵	person in tuxedo	person-role
🤵🏻	person in tuxedo: light skin tone	person-role
🤵🏼	person in tuxedo: medium-light skin tone	person-role
🤵🏽	person in tuxedo: medium skin tone	person-role
🤵🏾	person in tuxedo: medium-dark skin tone	person-role
🤵🏿	person in tuxedo: dark skin tone	person-role
🤵‍♂️	man in tuxedo	person-role
🤵🏻‍♂️	man in tuxedo: light skin tone	person-role
🤵🏼‍♂️	man in tuxedo: medium-light skin tone	person-role
🤵🏽‍♂️	man in tuxedo: medium skin tone	person-role
🤵🏾‍♂️	man in tuxedo: medium-dark skin tone	person-role
🤵🏿‍♂️	man in tuxedo: dark skin tone	person-role
🤵‍♀️	woman in tuxedo	person-role
🤵🏻‍♀️	woman in tuxedo: light skin tone	person-role
🤵🏼‍♀️	woman in tuxedo: medium-light skin tone	person-role
🤵🏽‍♀️	woman in tuxedo: medium skin tone	person-role
🤵🏾‍♀️	woman in tuxedo: medium-dark skin tone	person-role
🤵🏿‍♀️	woman in tuxedo: dark skin tone	person-role
👰	person with veil	person-role
👰🏻	person with veil: light skin tone	person-role
👰🏼	person with veil: medium-light skin tone	person-role
👰🏽	person with veil: medium skin tone	person-role
👰🏾	person with veil: medium-dark skin tone	person-role
👰🏿	person with veil: dark skin tone	person-role
👰‍♂️	man with veil	person-role
👰🏻‍♂️	man with veil: light skin tone	person-role
👰🏼‍♂️	man with veil: medium-light skin tone	person-role
👰🏽‍♂️	man with veil: medium skin tone	person-role
👰🏾‍♂️	man with veil: medium-dark skin tone	person-role
👰🏿‍♂️	man with veil: dark skin tone	person-role
👰‍♀️	woman with veil	person-role
👰🏻‍♀️	woman with veil: light skin tone	person-role
👰🏼‍♀️	woman with veil: medium-light skin tone	person-role
👰🏽‍♀️	woman with veil: medium skin tone	person-role
👰🏾‍♀️	woman with veil: medium-dark skin tone	person-role
👰🏿‍♀️	woman with veil: dark skin tone	person-role
🤰	pregnant woman	person-role
🤰🏻	pregnant woman: light skin tone	person-role
🤰🏼	pregnant woman: medium-light skin tone	person-role
🤰🏽	pregnant woman: medium skin tone	person-role
🤰🏾	pregnant woman: medium-dark skin tone	person-role
🤰🏿	pregnant woman: dark skin tone	person-role
🫃	pregnant man	person-role
🫃🏻	pregnant man: light skin tone	person-role
🫃🏼	pregnant man: medium-light skin tone	person-role
🫃🏽	pregnant man: medium skin tone	person-role
🫃🏾	pregnant man: medium-dark skin tone	person-role
🫃🏿	pregnant man: dark skin tone	person-role
🫄	pregnant person	person-role
🫄🏻	pregnant person: light skin tone	person-role
🫄🏼	pregnant person: medium-light skin tone	person-role
🫄🏽	pregnant person: medium skin tone	person-role
🫄🏾	pregnant person: medium-dark skin tone	person-role
🫄🏿	pregnant person: dark skin tone	person-role
🤱	breast-feeding	person-role
🤱🏻	breast-feeding: light skin tone	person-role
🤱🏼	breast-feeding: medium-light skin tone	person-role
🤱🏽	breast-feeding: medium skin tone	person-role
🤱🏾	breast-feeding: medium-dark skin tone	person-role
🤱🏿	breast-feeding: dark skin tone	person-role
👩‍🍼	woman feeding baby	person-role
👩🏻‍🍼	woman feeding baby: light skin tone	person-role
👩🏼‍🍼	woman feeding baby: medium-light skin tone	person-role
👩🏽‍🍼	woman feeding baby: medium skin tone	person-role
👩🏾‍🍼	woman feeding baby: medium-dark skin tone	person-role
👩🏿‍🍼	woman feeding baby: dark skin tone	person-role
👨‍🍼	man feeding baby	person-role
👨🏻‍🍼	man feeding baby: light skin tone	person-role
👨🏼‍🍼	man feeding baby: medium-light skin tone	person-role
👨🏽‍🍼	man feeding baby: medium skin tone	person-role
👨🏾‍🍼	man feeding baby: medium-dark skin tone	person-role
👨🏿‍🍼	man feeding baby: dark skin tone	person-role
🧑‍🍼	person feeding baby	person-role
🧑🏻‍🍼	person feeding baby: light skin tone	person-role
🧑🏼‍🍼	person feeding baby: medium-light skin tone	person-role
🧑🏽‍🍼	person feeding baby: medium skin tone	person-role
🧑🏾‍🍼	person feeding baby: medium-dark skin tone	person-role
🧑🏿‍🍼	person feeding baby: dark skin tone	person-role
👼	baby angel	person-fantasy
👼🏻	baby angel: light skin tone	person-fantasy
👼🏼	baby angel: medium-light skin tone	person-fantasy
👼🏽	baby angel: medium skin tone	person-fantasy
👼🏾	baby angel: medium-dark skin tone	person-fantasy
👼🏿	baby angel: dark skin tone	person-fantasy
🎅	Santa Claus	person-fantasy
🎅🏻	Santa Claus: light skin tone	person-fantasy
🎅🏼	Santa Claus: medium-light skin tone	person-fantasy
🎅🏽	Santa Claus: medium skin tone	person-fantasy
🎅🏾	Santa Claus: medium-dark skin tone	person-fantasy
🎅🏿	Santa Claus: dark skin tone	person-fantasy
🤶	Mrs. Claus	person-fantasy
🤶🏻	Mrs. Claus: light skin tone	person-fantasy
🤶🏼	Mrs. Claus: medium-light skin tone	person-fantasy
🤶🏽	Mrs. Claus: medium skin tone	person-fantasy
🤶🏾	Mrs. Claus: medium-dark skin tone	person-fantasy
🤶🏿	Mrs. Claus: dark skin tone	person-fantasy
🧑‍🎄	Mx Claus	person-fantasy
🧑🏻‍🎄	Mx Claus: light skin tone	person-fantasy
🧑🏼‍🎄	Mx Claus: medium-light skin tone	person-fantasy
🧑🏽‍🎄	Mx Claus: medium skin tone	person-fantasy
🧑🏾‍🎄	Mx Claus: medium-dark skin tone	person-fantasy
🧑🏿‍🎄	Mx Claus: dark skin tone	person-fantasy
🦸	superhero	person-fantasy
🦸🏻	superhero: light skin tone	person-fantasy
🦸🏼	superhero: medium-light skin tone	person-fantasy
🦸🏽	superhero: medium skin tone	person-fantasy
🦸🏾	superhero: medium-dark skin tone	person-fantasy
🦸🏿	superhero: dark skin tone	person-fantasy
🦸‍♂️	man superhero	person-fantasy
🦸🏻‍♂️	man superhero: light skin tone	person-fantasy
🦸🏼‍♂️	man superhero: medium-light skin tone	person-fantasy
🦸🏽‍♂️	man superhero: medium skin tone	person-fantasy
🦸🏾‍♂️	man superhero: medium-dark skin tone	person-fantasy
🦸🏿‍♂️	man superhero: dark skin tone	person-fantasy
🦸‍♀️	woman superhero	person-fantasy
🦸🏻‍♀️	woman superhero: light skin tone	person-fantasy
🦸🏼‍♀️	woman superhero: medium-light skin tone	person-fantasy
🦸🏽‍♀️	woman superhero: medium skin tone	person-fantasy
🦸🏾‍♀️	woman superhero: medium-dark skin tone	person-fantasy
🦸🏿‍♀️	woman superhero: dark skin tone	person-fantasy
🦹	supervillain	person-fantasy
🦹🏻	supervillain: light skin tone	person-fantasy
🦹🏼	supervillain: medium-light skin tone	person-fantasy
🦹🏽	supervillain: medium skin tone	person-fantasy
🦹🏾	supervillain: medium-dark skin tone	person-fantasy
🦹🏿	supervillain: dark skin tone	person-fantasy
🦹‍♂️	man supervillain	person-fantasy
🦹🏻‍♂️	man supervillain: light skin tone	person-fantasy
🦹🏼‍♂️	man supervillain: medium-light skin tone	person-fantasy
🦹🏽‍♂️	man supervillain: medium skin tone	person-fantasy
🦹🏾‍♂️	man supervillain: medium-dark skin tone	person-fantasy
🦹🏿‍♂️	man supervillain: dark skin tone	person-fantasy
🦹‍♀️	woman supervillain	person-fantasy
🦹🏻‍♀️	woman supervillain: light skin tone	person-fantasy
🦹🏼‍♀️	woman supervillain: medium-light skin tone	person-fantasy
🦹🏽‍♀️	woman supervillain: medium skin tone	person-fantasy
🦹🏾‍♀️	woman supervillain: medium-dark skin tone	person-fantasy
🦹🏿‍♀️	woman supervillain: dark skin tone	person-fantasy
🧙	mage	person-fantasy
🧙🏻	mage: light skin tone	person-fantasy
🧙🏼	mage: medium-light skin tone	person-fantasy
🧙🏽	mage: medium skin tone	person-fantasy
🧙🏾	mage: medium-dark skin tone	person-fantasy
🧙🏿	mage: dark skin tone	person-fantasy
🧙‍♂️	man mage	person-fantasy
🧙🏻‍♂️	man mage: light skin tone	person-fantasy
🧙🏼‍♂️	man mage: medium-light skin tone	person-fantasy
🧙🏽‍♂️	man mage: medium skin tone	person-fantasy
🧙🏾‍♂️	man mage: medium-dark skin tone	person-fantasy
🧙🏿‍♂️	man mage: dark skin tone	person-fantasy
🧙‍♀️	woman mage	person-fantasy
🧙🏻‍♀️	woman mage: light skin tone	person-fantasy
🧙🏼‍♀️	woman mage: medium-light skin tone	person-fantasy
🧙🏽‍♀️	woman mage: medium skin tone	person-fantasy
🧙🏾‍♀️	woman mage: medium-dark skin tone	person-fantasy
🧙🏿‍♀️	woman mage: dark skin tone	person-fantasy
🧚	fairy	person-fantasy
🧚🏻	fairy: light skin tone	person-fantasy
🧚🏼	fairy: medium-light skin tone	person-fantasy
🧚🏽	fairy: medium skin tone	person-fantasy
🧚🏾	fairy: medium-dark skin tone	person-fantasy
🧚🏿	fairy: dark skin tone	person-fantasy
🧚‍♂️	man fairy	person-fantasy
🧚🏻‍♂️	man fairy: light skin tone	person-fantasy
🧚🏼‍♂️	man fairy: medium-light skin tone	person-fantasy
🧚🏽‍♂️	man fairy: medium skin tone	person-fantasy
🧚🏾‍♂️	man fairy: medium-dark skin tone	person-fantasy
🧚🏿‍♂️	man fairy: dark skin tone	person-fantasy
🧚‍♀️	woman fairy	person-fantasy
🧚🏻‍♀️	woman fairy: light skin tone	person-fantasy
🧚🏼‍♀️	woman fairy: medium-light skin tone	person-fantasy
🧚🏽‍♀️	woman fairy: medium skin tone	person-fantasy
🧚🏾‍♀️	woman fairy: medium-dark skin tone	person-fantasy
🧚🏿‍♀️	woman fairy: dark skin tone	person-fantasy
🧛	vampire	person-fantasy
🧛🏻	vampire: light skin tone	person-fantasy
🧛🏼	vampire: medium-light skin tone	person-fantasy
🧛🏽	vampire: medium skin tone	person-fantasy
🧛🏾	vampire: medium-dark skin tone	person-fantasy
🧛🏿	vampire: dark skin tone	person-fantasy
🧛‍♂️	man vampire	person-fantasy
🧛🏻‍♂️	man vampire: light skin tone	person-fantasy
🧛🏼‍♂️	man vampire: medium-light skin tone	person-fantasy
🧛🏽‍♂️	man vampire: medium skin tone	person-fantasy
🧛🏾‍♂️	man vampire: medium-dark skin tone	person-fantasy
🧛🏿‍♂️	man vampire: dark skin tone	person-fantasy
🧛‍♀️	woman vampire	person-fantasy
🧛🏻‍♀️	woman vampire: light skin tone	person-fantasy
🧛🏼‍♀️	woman vampire: medium-light skin tone	person-fantasy
🧛🏽‍♀️	woman vampire: medium skin tone	person-fantasy
🧛🏾‍♀️	woman vampire: medium-dark skin tone	person-fantasy
🧛🏿‍♀️	woman vampire: dark skin tone	person-fantasy
🧜	merperson	person-fantasy
🧜🏻	merperson: light skin tone	person-fantasy
🧜🏼	merperson: medium-light skin tone	person-fantasy
🧜🏽	merperson: medium skin tone	person-fantasy
🧜🏾	merperson: medium-dark skin tone	person-fantasy
🧜🏿	merperson: dark skin tone	person-fantasy
🧜‍♂️	merman	person-fantasy
🧜🏻‍♂️	merman: light skin tone	person-fantasy
🧜🏼‍♂️	merman: medium-light skin tone	person-fantasy
🧜🏽‍♂️	merman: medium skin tone	person-fantasy
🧜🏾‍♂️	merman: medium-dark skin tone	person-fantasy
🧜🏿‍♂️	merman: dark skin tone	person-fantasy
🧜‍♀️	mermaid	person-fantasy
🧜🏻‍♀️	mermaid: light skin tone	person-fantasy
🧜🏼‍♀️	mermaid: medium-light skin tone	person-fantasy
🧜🏽‍♀️	mermaid: medium skin tone	person-fantasy
🧜🏾‍♀️	mermaid: medium-dark skin tone	person-fantasy
🧜🏿‍♀️	mermaid: dark skin tone	person-fantasy
🧝	elf	person-fantasy
🧝🏻	elf: light skin tone	person-fantasy
🧝🏼	elf: medium-light skin tone	person-fantasy
🧝🏽	elf: medium skin tone	person-fantasy
🧝🏾	elf: medium-dark skin tone	person-fantasy
🧝🏿	elf: dark skin tone	person-fantasy
🧝‍♂️	man elf	person-fantasy
🧝🏻‍♂️	man elf: light skin tone	person-fantasy
🧝🏼‍♂️	man elf: medium-light skin tone	person-fantasy
🧝🏽‍♂️	man elf: medium skin tone	person-fantasy
🧝🏾‍♂️	man elf: medium-dark skin tone	person-fantasy
🧝🏿‍♂️	man elf: dark skin tone	person-fantasy
🧝‍♀️	woman elf	person-fantasy
🧝🏻‍♀️	woman elf: light skin tone	person-fantasy
🧝🏼‍♀️	woman elf: medium-light skin tone	person-fantasy
🧝🏽‍♀️	woman elf: medium skin tone	person-fantasy
🧝🏾‍♀️	woman elf: medium-dark skin tone	person-fantasy
🧝🏿‍♀️	woman elf: dark skin tone	person-fantasy
🧞	genie	person-fantasy
🧞‍♂️	man genie	person-fantasy
🧞‍♀️	woman genie	person-fantasy
🧟	zombie	person-fantasy
🧟‍♂️	man zombie	person-fantasy
🧟‍♀️	woman zombie	person-fantasy
🧌	troll	person-fantasy
🫈	hairy creature	person-fantasy
💆	person getting massage	person-activity
💆🏻	person getting massage: light skin tone	person-activity
💆🏼	person getting massage: medium-light skin tone	person-activity
💆🏽	person getting massage: medium skin tone	person-activity
💆🏾	person getting massage: medium-dark skin tone	person-activity
💆🏿	person getting massage: dark skin tone	person-activity
💆‍♂️	man getting massage	person-activity
💆🏻‍♂️	man getting massage: light skin tone	person-activity
💆🏼‍♂️	man getting massage: medium-light skin tone	person-activity
💆🏽‍♂️	man getting massage: medium skin tone	person-activity
💆🏾‍♂️	man getting massage: medium-dark skin tone	person-activity
💆🏿‍♂️	man getting massage: dark skin tone	person-activity
💆‍♀️	woman getting massage	person-activity
💆🏻‍♀️	woman getting massage: light skin tone	person-activity
💆🏼‍♀️	woman getting massage: medium-light skin tone	person-activity
💆🏽‍♀️	woman getting massage: medium skin tone	person-activity
💆🏾‍♀️	woman getting massage: medium-dark skin tone	person-activity
💆🏿‍♀️	woman getting massage: dark skin tone	person-activity
💇	person getting haircut	person-activity
💇🏻	person getting haircut: light skin tone	person-activity
💇🏼	person getting haircut: medium-light skin tone	person-activity
💇🏽	person getting haircut: medium skin tone	person-activity
💇🏾	person getting haircut: medium-dark skin tone	person-activity
💇🏿	person getting haircut: dark skin tone	person-activity
💇‍♂️	man getting haircut	person-activity
💇🏻‍♂️	man getting haircut: light skin tone	person-activity
💇🏼‍♂️	man getting haircut: medium-light skin tone	person-activity
💇🏽‍♂️	man getting haircut: medium skin tone	person-activity
💇🏾‍♂️	man getting haircut: medium-dark skin tone	person-activity
💇🏿‍♂️	man getting haircut: dark skin tone	person-activity
💇‍♀️	woman getting haircut	person-activity
💇🏻‍♀️	woman getting haircut: light skin tone	person-activity
💇🏼‍♀️	woman getting haircut: medium-light skin tone	person-activity
💇🏽‍♀️	woman getting haircut: medium skin tone	person-activity
💇🏾‍♀️	woman getting haircut: medium-dark skin tone	person-activity
💇🏿‍♀️	woman getting haircut: dark skin tone	person-activity
🚶	person walking	person-activity
🚶🏻	person walking: light skin tone	person-activity
🚶🏼	person walking: medium-light skin tone	person-activity
🚶🏽	person walking: medium skin tone	person-activity
🚶🏾	person walking: medium-dark skin tone	person-activity
🚶🏿	person walking: dark skin tone	person-activity
🚶‍♂️	man walking	person-activity
🚶🏻‍♂️	man walking: light skin tone	person-activity
🚶🏼‍♂️	man walking: medium-light skin tone	person-activity
🚶🏽‍♂️	man walking: medium skin tone	person-activity
🚶🏾‍♂️	man walking: medium-dark skin tone	person-activity
🚶🏿‍♂️	man walking: dark skin tone	person-activity
🚶‍♀️	woman walking	person-activity
🚶🏻‍♀️	woman walking: light skin tone	person-activity
🚶🏼‍♀️	woman walking: medium-light skin tone	person-activity
🚶🏽‍♀️	woman walking: medium skin tone	person-activity
🚶🏾‍♀️	woman walking: medium-dark skin tone	person-activity
🚶🏿‍♀️	woman walking: dark skin tone	person-activity
🚶‍➡️	person walking facing right	person-activity
🚶🏻‍➡️	person walking facing right: light skin tone	person-activity
🚶🏼‍➡️	person walking facing right: medium-light skin tone	person-activity
🚶🏽‍➡️	person walking facing right: medium skin tone	person-activity
🚶🏾‍➡️	person walking facing right: medium-dark skin tone	person-activity
🚶🏿‍➡️	person walking facing right: dark skin tone	person-activity
🚶‍♀️‍➡️	woman walking facing right	person-activity
🚶🏻‍♀️‍➡️	woman walking facing right: light skin tone	person-activity
🚶🏼‍♀️‍➡️	woman walking facing right: medium-light skin tone	person-activity
🚶🏽‍♀️‍➡️	woman walking facing right: medium skin tone	person-activity
🚶🏾‍♀️‍➡️	woman walking facing right: medium-dark skin tone	person-activity
🚶🏿‍♀️‍➡️	woman walking facing right: dark skin tone	person-activity
🚶‍♂️‍➡️	man walking facing right	person-activity
🚶🏻‍♂️‍➡️	man walking facing right: light skin tone	person-activity
🚶🏼‍♂️‍➡️	man walking facing right: medium-light skin tone	person-activity
🚶🏽‍♂️‍➡️	man walking facing right: medium skin tone	person-activity
🚶🏾‍♂️‍➡️	man walking facing right: medium-dark skin tone	person-activity
🚶🏿‍♂️‍➡️	man walking facing right: dark skin tone	person-activity
🧍	person standing	person-activity
🧍🏻	person standing: light skin tone	person-activity
🧍🏼	person standing: medium-light skin tone	person-activity
🧍🏽	person standing: medium skin tone	person-activity
🧍🏾	person standing: medium-dark skin tone	person-activity
🧍🏿	person standing: dark skin tone	person-activity
🧍‍♂️	man standing	person-activity
🧍🏻‍♂️	man standing: light skin tone	person-activity
🧍🏼‍♂️	man standing: medium-light skin tone	person-activity
🧍🏽‍♂️	man standing: medium skin tone	person-activity
🧍🏾‍♂️	man standing: medium-dark skin tone	person-activity
🧍🏿‍♂️	man standing: dark skin tone	person-activity
🧍‍♀️	woman standing	person-activity
🧍🏻‍♀️	woman standing: light skin tone	person-activity
🧍🏼‍♀️	woman standing: medium-light skin tone	person-activity
🧍🏽‍♀️	woman standing: medium skin tone	person-activity
🧍🏾‍♀️	woman standing: medium-dark skin tone	person-activity
🧍🏿‍♀️	woman standing: dark skin tone	person-activity
🧎	person kneeling	person-activity
🧎🏻	person kneeling: light skin tone	person-activity
🧎🏼	person kneeling: medium-light skin tone	person-activity
🧎🏽	person kneeling: medium skin tone	person-activity
🧎🏾	person kneeling: medium-dark skin tone	person-activity
🧎🏿	person kneeling: dark skin tone	person-activity
🧎‍♂️	man kneeling	person-activity
🧎🏻‍♂️	man kneeling: light skin tone	person-activity
🧎🏼‍♂️	man kneeling: medium-light skin tone	person-activity
🧎🏽‍♂️	man kneeling: medium skin tone	person-activity
🧎🏾‍♂️	man kneeling: medium-dark skin tone	person-activity
🧎🏿‍♂️	man kneeling: dark skin tone	person-activity
🧎‍♀️	woman kneeling	person-activity
🧎🏻‍♀️	woman kneeling: light skin tone	person-activity
🧎🏼‍♀️	woman kneeling: medium-light skin tone	person-activity
🧎🏽‍♀️	woman kneeling: medium skin tone	person-activity
🧎🏾‍♀️	woman kneeling: medium-dark skin tone	person-activity
🧎🏿‍♀️	woman kneeling: dark skin tone	person-activity
🧎‍➡️	person kneeling facing right	person-activity
🧎🏻‍➡️	person kneeling facing right: light skin tone	person-activity
🧎🏼‍➡️	person kneeling facing right: medium-light skin tone	person-activity
🧎🏽‍➡️	person kneeling facing right: medium skin tone	person-activity
🧎🏾‍➡️	person kneeling facing right: medium-dark skin tone	person-activity
🧎🏿‍➡️	person kneeling facing right: dark skin tone	person-activity
🧎‍♀️‍➡️	woman kneeling facing right	person-activity
🧎🏻‍♀️‍➡️	woman kneeling facing right: light skin tone	person-activity
🧎🏼‍♀️‍➡️	woman kneeling facing right: medium-light skin tone	person-activity
🧎🏽‍♀️‍➡️	woman kneeling facing right: medium skin tone	person-activity
🧎🏾‍♀️‍➡️	woman kneeling facing right: medium-dark skin tone	person-activity
🧎🏿‍♀️‍➡️	woman kneeling facing right: dark skin tone	person-activity
🧎‍♂️‍➡️	man kneeling facing right	person-activity
🧎🏻‍♂️‍➡️	man kneeling facing right: light skin tone	person-activity
🧎🏼‍♂️‍➡️	man kneeling facing right: medium-light skin tone	person-activity
🧎🏽‍♂️‍➡️	man kneeling facing right: medium skin tone	person-activity
🧎🏾‍♂️‍➡️	man kneeling facing right: medium-dark skin tone	person-activity
🧎🏿‍♂️‍➡️	man kneeling facing right: dark skin tone	person-activity
🧑‍🦯	person with white cane	person-activity
🧑🏻‍🦯	person with white cane: light skin tone	person-activity
🧑🏼‍🦯	person with white cane: medium-light skin tone	person-activity
🧑🏽‍🦯	person with white cane: medium skin tone	person-activity
🧑🏾‍🦯	person with white cane: medium-dark skin tone	person-activity
🧑🏿‍🦯	person with white cane: dark skin tone	person-activity
🧑‍🦯‍➡️	person with white cane facing right	person-activity
🧑🏻‍🦯‍➡️	person with white cane facing right: light skin tone	person-activity
🧑🏼‍🦯‍➡️	person with white cane facing right: medium-light skin tone	person-activity
🧑🏽‍🦯‍➡️	person with white cane facing right: medium skin tone	person-activity
🧑🏾‍🦯‍➡️	person with white cane facing right: medium-dark skin tone	person-activity
🧑🏿‍🦯‍➡️	person with white cane facing right: dark skin tone	person-activity
👨‍🦯	man with white cane	person-activity
👨🏻‍🦯	man with white cane: light skin tone	person-activity
👨🏼‍🦯	man with white cane: medium-light skin tone	person-activity
👨🏽‍🦯	man with white cane: medium skin tone	person-activity
👨🏾‍🦯	man with white cane: medium-dark skin tone	person-activity
👨🏿‍🦯	man with white cane: dark skin tone	person-activity
👨‍🦯‍➡️	man with white cane facing right	person-activity
👨🏻‍🦯‍➡️	man with white cane facing right: light skin tone	person-activity
👨🏼‍🦯‍➡️	man with white cane facing right: medium-light skin tone	person-activity
👨🏽‍🦯‍➡️	man with white cane facing right: medium skin tone	person-activity
👨🏾‍🦯‍➡️	man with white cane facing right: medium-dark skin tone	person-activity
👨🏿‍🦯‍➡️	man with white cane facing right: dark skin tone	person-activity
👩‍🦯	woman with white cane	person-activity
👩🏻‍🦯	woman with white cane: light skin tone	person-activity
👩🏼‍🦯	woman with white cane: medium-light skin tone	person-activity
👩🏽‍🦯	woman with white cane: medium skin tone	person-activity
👩🏾‍🦯	woman with white cane: medium-dark skin tone	person-activity
👩🏿‍🦯	woman with white cane: dark skin tone	person-activity
👩‍🦯‍➡️	woman with white cane facing right	person-activity
👩🏻‍🦯‍➡️	woman with white cane facing right: light skin tone	person-activity
👩🏼‍🦯‍➡️	woman with white cane facing right: medium-light skin tone	person-activity
👩🏽‍🦯‍➡️	woman with white cane facing right: medium skin tone	person-activity
👩🏾‍🦯‍➡️	woman with white cane facing right: medium-dark skin tone	person-activity
👩🏿‍🦯‍➡️	woman with white cane facing right: dark skin tone	person-activity
🧑‍🦼	person in motorized wheelchair	person-activity
🧑🏻‍🦼	person in motorized wheelchair: light skin tone	person-activity
🧑🏼‍🦼	person in motorized wheelchair: medium-light skin tone	person-activity
🧑🏽‍🦼	person in motorized wheelchair: medium skin tone	person-activity
🧑🏾‍🦼	person in motorized wheelchair: medium-dark skin tone	person-activity
🧑🏿‍🦼	person in motorized wheelchair: dark skin tone	person-activity
🧑‍🦼‍➡️	person in motorized wheelchair facing right	person-activity
🧑🏻‍🦼‍➡️	person in motorized wheelchair facing right: light skin tone	person-activity
🧑🏼‍🦼‍➡️	person in motorized wheelchair facing right: medium-light skin tone	person-activity
🧑🏽‍🦼‍➡️	person in motorized wheelchair facing right: medium skin tone	person-activity
🧑🏾‍🦼‍➡️	person in motorized wheelchair facing right: medium-dark skin tone	person-activity
🧑🏿‍🦼‍➡️	person in motorized wheelchair facing right: dark skin tone	person-activity
👨‍🦼	man in motorized wheelchair	person-activity
👨🏻‍🦼	man in motorized wheelchair: light skin tone	person-activity
👨🏼‍🦼	man in motorized wheelchair: medium-light skin tone	person-activity
👨🏽‍🦼	man in motorized wheelchair: medium skin tone	person-activity
👨🏾‍🦼	man in motorized wheelchair: medium-dark skin tone	person-activity
👨🏿‍🦼	man in motorized wheelchair: dark skin tone	person-activity
👨‍🦼‍➡️	man in motorized wheelchair facing right	person-activity
👨🏻‍🦼‍➡️	man in motorized wheelchair facing right: light skin tone	person-activity
👨🏼‍🦼‍➡️	man in motorized wheelchair facing right: medium-light skin tone	person-activity
👨🏽‍🦼‍➡️	man in motorized wheelchair facing right: medium skin tone	person-activity
👨🏾‍🦼‍➡️	man in motorized wheelchair facing right: medium-dark skin tone	person-activity
👨🏿‍🦼‍➡️	man in motorized wheelchair facing right: dark skin tone	person-activity
👩‍🦼	woman in motorized wheelchair	person-activity
👩🏻‍🦼	woman in motorized wheelchair: light skin tone	person-activity
👩🏼‍🦼	woman in motorized wheelchair: medium-light skin tone	person-activity
👩🏽‍🦼	woman in motorized wheelchair: medium skin tone	person-activity
👩🏾‍🦼	woman in motorized wheelchair: medium-dark skin tone	person-activity
👩🏿‍🦼	woman in motorized wheelchair: dark skin tone	person-activity
👩‍🦼‍➡️	woman in motorized wheelchair facing right	person-activity
👩🏻‍🦼‍➡️	woman in motorized wheelchair facing right: light skin tone	person-activity
👩🏼‍🦼‍➡️	woman in motorized wheelchair facing right: medium-light skin tone	person-activity
👩🏽‍🦼‍➡️	woman in motorized wheelchair facing right: medium skin tone	person-activity
👩🏾‍🦼‍➡️	woman in motorized wheelchair facing right: medium-dark skin tone	person-activity
👩🏿‍🦼‍➡️	woman in motorized wheelchair facing right: dark skin tone	person-activity
🧑‍🦽	person in manual wheelchair	person-activity
🧑🏻‍🦽	person in manual wheelchair: light skin tone	person-activity
🧑🏼‍🦽	person in manual wheelchair: medium-light skin tone	person-activity
🧑🏽‍🦽	person in manual wheelchair: medium skin tone	person-activity
🧑🏾‍🦽	person in manual wheelchair: medium-dark skin tone	person-activity
🧑🏿‍🦽	person in manual wheelchair: dark skin tone	person-activity
🧑‍🦽‍➡️	person in manual wheelchair facing right	person-activity
🧑🏻‍🦽‍➡️	person in manual wheelchair facing right: light skin tone	person-activity
🧑🏼‍🦽‍➡️	person in manual wheelchair facing right: medium-light skin tone	person-activity
🧑🏽‍🦽‍➡️	person in manual wheelchair facing right: medium skin tone	person-activity
🧑🏾‍🦽‍➡️	person in manual wheelchair facing right: medium-dark skin tone	person-activity
🧑🏿‍🦽‍➡️	person in manual wheelchair facing right: dark skin tone	person-activity
👨‍🦽	man in manual wheelchair	person-activity
👨🏻‍🦽	man in manual wheelchair: light skin tone	person-activity
👨🏼‍🦽	man in manual wheelchair: medium-light skin tone	person-activity
👨🏽‍🦽	man in manual wheelchair: medium skin tone	person-activity
👨🏾‍🦽	man in manual wheelchair: medium-dark skin tone	person-activity
👨🏿‍🦽	man in manual wheelchair: dark skin tone	person-activity
👨‍🦽‍➡️	man in manual wheelchair facing right	person-activity
👨🏻‍🦽‍➡️	man in manual wheelchair facing right: light skin tone	person-activity
👨🏼‍🦽‍➡️	man in manual wheelchair facing right: medium-light skin tone	person-activity
👨🏽‍🦽‍➡️	man in manual wheelchair facing right: medium skin tone	person-activity
👨🏾‍🦽‍➡️	man in manual wheelchair facing right: medium-dark skin tone	person-activity
👨🏿‍🦽‍➡️	man in manual wheelchair facing right: dark skin tone	person-activity
👩‍🦽	woman in manual wheelchair	person-activity
👩🏻‍🦽	woman in manual wheelchair: light skin tone	person-activity
👩🏼‍🦽	woman in manual wheelchair: medium-light skin tone	person-activity
👩🏽‍🦽	woman in manual wheelchair: medium skin tone	person-activity
👩🏾‍🦽	woman in manual wheelchair: medium-dark skin tone	person-activity
👩🏿‍🦽	woman in manual wheelchair: dark skin tone	person-activity
👩‍🦽‍➡️	woman in manual wheelchair facing right	person-activity
👩🏻‍🦽‍➡️	woman in manual wheelchair facing right: light skin tone	person-activity
👩🏼‍🦽‍➡️	woman in manual wheelchair facing right: medium-light skin tone	person-activity
👩🏽‍🦽‍➡️	woman in manual wheelchair facing right: medium skin tone	person-activity
👩🏾‍🦽‍➡️	woman in manual wheelchair facing right: medium-dark skin tone	person-activity
👩🏿‍🦽‍➡️	woman in manual wheelchair facing right: dark skin tone	person-activity
🏃	person running	person-activity
🏃🏻	person running: light skin tone	person-activity
🏃🏼	person running: medium-light skin tone	person-activity
🏃🏽	person running: medium skin tone	person-activity
🏃🏾	person running: medium-dark skin tone	person-activity
🏃🏿	person running: dark skin tone	person-activity
🏃‍♂️	man running	person-activity
🏃🏻‍♂️	man running: light skin tone	person-activity
🏃🏼‍♂️	man running: medium-light skin tone	person-activity
🏃🏽‍♂️	man running: medium skin tone	person-activity
🏃🏾‍♂️	man running: medium-dark skin tone	person-activity
🏃🏿‍♂️	man running: dark skin tone	person-activity
🏃‍♀️	woman running	person-activity
🏃🏻‍♀️	woman running: light skin tone	person-activity
🏃🏼‍♀️	woman running: medium-light skin tone	person-activity
🏃🏽‍♀️	woman running: medium skin tone	person-activity
🏃🏾‍♀️	woman running: medium-dark skin tone	person-activity
🏃🏿‍♀️	woman running: dark skin tone	person-activity
🏃‍➡️	person running facing right	person-activity
🏃🏻‍➡️	person running facing right: light skin tone	person-activity
🏃🏼‍➡️	person running facing right: medium-light skin tone	person-activity
🏃🏽‍➡️	person running facing right: medium skin tone	person-activity
🏃🏾‍➡️	person running facing right: medium-dark skin tone	person-activity
🏃🏿‍➡️	person running facing right: dark skin tone	person-activity
🏃‍♀️‍➡️	woman running facing right	person-activity
🏃🏻‍♀️‍➡️	woman running facing right: light skin tone	person-activity
🏃🏼‍♀️‍➡️	woman running facing right: medium-light skin tone	person-activity
🏃🏽‍♀️‍➡️	woman running facing right: medium skin tone	person-activity
🏃🏾‍♀️‍➡️	woman running facing right: medium-dark skin tone	person-activity
🏃🏿‍♀️‍➡️	woman running facing right: dark skin tone	person-activity
🏃‍♂️‍➡️	man running facing right	person-activity
🏃🏻‍♂️‍➡️	man running facing right: light skin tone	person-activity
🏃🏼‍♂️‍➡️	man running facing right: medium-light skin tone	person-activity
🏃🏽‍♂️‍➡️	man running facing right: medium skin tone	person-activity
🏃🏾‍♂️‍➡️	man running facing right: medium-dark skin tone	person-activity
🏃🏿‍♂️‍➡️	man running facing right: dark skin tone	person-activity
🧑‍🩰	ballet dancer	person-activity
🧑🏻‍🩰	ballet dancer: light skin tone	person-activity
🧑🏼‍🩰	ballet dancer: medium-light skin tone	person-activity
🧑🏽‍🩰	ballet dancer: medium skin tone	person-activity
🧑🏾‍🩰	ballet dancer: medium-dark skin tone	person-activity
🧑🏿‍🩰	ballet dancer: dark skin tone	person-activity
💃	woman dancing	person-activity
💃🏻	woman dancing: light skin tone	person-activity
💃🏼	woman dancing: medium-light skin tone	person-activity
💃🏽	woman dancing: medium skin tone	person-activity
💃🏾	woman dancing: medium-dark skin tone	person-activity
💃🏿	woman dancing: dark skin tone	person-activity
🕺	man dancing	person-activity
🕺🏻	man dancing: light skin tone	person-activity
🕺🏼	man dancing: medium-light skin tone	person-activity
🕺🏽	man dancing: medium skin tone	person-activity
🕺🏾	man dancing: medium-dark skin tone	person-activity
🕺🏿	man dancing: dark skin tone	person-activity
🕴️	person in suit levitating	person-activity
🕴🏻	person in suit levitating: light skin tone	person-activity
🕴🏼	person in suit levitating: medium-light skin tone	person-activity
🕴🏽	person in suit levitating: medium skin tone	person-activity
🕴🏾	person in suit levitating: medium-dark skin tone	person-activity
🕴🏿	person in suit levitating: dark skin tone	person-activity
👯	people with bunny ears	person-activity
👯🏻	people with bunny ears: light skin tone	person-activity
👯🏼	people with bunny ears: medium-light skin tone	person-activity
👯🏽	people with bunny ears: medium skin tone	person-activity
👯🏾	people with bunny ears: medium-dark skin tone	person-activity
👯🏿	people with bunny ears: dark skin tone	person-activity
👯‍♂️	men with bunny ears	person-activity
👯🏻‍♂️	men with bunny ears: light skin tone	person-activity
👯🏼‍♂️	men with bunny ears: medium-light skin tone	person-activity
👯🏽‍♂️	men with bunny ears: medium skin tone	person-activity
👯🏾‍♂️	men with bunny ears: medium-dark skin tone	person-activity
👯🏿‍♂️	men with bunny ears: dark skin tone	person-activity
👯‍♀️	women with bunny ears	person-activity
👯🏻‍♀️	women with bunny ears: light skin tone	person-activity
👯🏼‍♀️	women with bunny ears: medium-light skin tone	person-activity
👯🏽‍♀️	women with bunny ears: medium skin tone	person-activity
👯🏾‍♀️	women with bunny ears: medium-dark skin tone	person-activity
👯🏿‍♀️	women with bunny ears: dark skin tone	person-activity
🧑🏻‍🐰‍🧑🏼	people with bunny ears: light skin tone, medium-light skin tone	person-activity
🧑🏻‍🐰‍🧑🏽	people with bunny ears: light skin tone, medium skin tone	person-activity
🧑🏻‍🐰‍🧑🏾	people with bunny ears: light skin tone, medium-dark skin tone	person-activity
🧑🏻‍🐰‍🧑🏿	people with bunny ears: light skin tone, dark skin tone	person-activity
🧑🏼‍🐰‍🧑🏻	people with bunny ears: medium-light skin tone, light skin tone	person-activity
🧑🏼‍🐰‍🧑🏽	people with bunny ears: medium-light skin tone, medium skin tone	person-activity
🧑🏼‍🐰‍🧑🏾	people with bunny ears: medium-light skin tone, medium-dark skin tone	person-activity
🧑🏼‍🐰‍🧑🏿	people with bunny ears: medium-light skin tone, dark skin tone	person-activity
🧑🏽‍🐰‍🧑🏻	people with bunny ears: medium skin tone, light skin tone	person-activity
🧑🏽‍🐰‍🧑🏼	people with bunny ears: medium skin tone, medium-light skin tone	person-activity
🧑🏽‍🐰‍🧑🏾	people with bunny ears: medium skin tone, medium-dark skin tone	person-activity
🧑🏽‍🐰‍🧑🏿	people with bunny ears: medium skin tone, dark skin tone	person-activity
🧑🏾‍🐰‍🧑🏻	people with bunny ears: medium-dark skin tone, light skin tone	person-activity
🧑🏾‍🐰‍🧑🏼	people with bunny ears: medium-dark skin tone, medium-light skin tone	person-activity
🧑🏾‍🐰‍🧑🏽	people with bunny ears: medium-dark skin tone, medium skin tone	person-activity
🧑🏾‍🐰‍🧑🏿	people with bunny ears: medium-dark skin tone, dark skin tone	person-activity
🧑🏿‍🐰‍🧑🏻	people with bunny ears: dark skin tone, light skin tone	person-activity
🧑🏿‍🐰‍🧑🏼	people with bunny ears: dark skin tone, medium-light skin tone	person-activity
🧑🏿‍🐰‍🧑🏽	people with bunny ears: dark skin tone, medium skin tone	person-activity
🧑🏿‍🐰‍🧑🏾	people with bunny ears: dark skin tone, medium-dark skin tone	person-activity
👨🏻‍🐰‍👨🏼	men with bunny ears: light skin tone, medium-light skin tone	person-activity
👨🏻‍🐰‍👨🏽	men with bunny ears: light skin tone, medium skin tone	person-activity
👨🏻‍🐰‍👨🏾	men with bunny ears: light skin tone, medium-dark skin tone	person-activity
👨🏻‍🐰‍👨🏿	men with bunny ears: light skin tone, dark skin tone	person-activity
👨🏼‍🐰‍👨🏻	men with bunny ears: medium-light skin tone, light skin tone	person-activity
👨🏼‍🐰‍👨🏽	men with bunny ears: medium-light skin tone, medium skin tone	person-activity
👨🏼‍🐰‍👨🏾	men with bunny ears: medium-light skin tone, medium-dark skin tone	person-activity
👨🏼‍🐰‍👨🏿	men with bunny ears: medium-light skin tone, dark skin tone	person-activity
👨🏽‍🐰‍👨🏻	men with bunny ears: medium skin tone, light skin tone	person-activity
👨🏽‍🐰‍👨🏼	men with bunny ears: medium skin tone, medium-light skin tone	person-activity
👨🏽‍🐰‍👨🏾	men with bunny ears: medium skin tone, medium-dark skin tone	person-activity
👨🏽‍🐰‍👨🏿	men with bunny ears: medium skin tone, dark skin tone	person-activity
👨🏾‍🐰‍👨🏻	men with bunny ears: medium-dark skin tone, light skin tone	person-activity
👨🏾‍🐰‍👨🏼	men with bunny ears: medium-dark skin tone, medium-light skin tone	person-activity
👨🏾‍🐰‍👨🏽	men with bunny ears: medium-dark skin tone, medium skin tone	person-activity
👨🏾‍🐰‍👨🏿	men with bunny ears: medium-dark skin tone, dark skin tone	person-activity
👨🏿‍🐰‍👨🏻	men with bunny ears: dark skin tone, light skin tone	person-activity
👨🏿‍🐰‍👨🏼	men with bunny ears: dark skin tone, medium-light skin tone	person-activity
👨🏿‍🐰‍👨🏽	men with bunny ears: dark skin tone, medium skin tone	person-activity
👨🏿‍🐰‍👨🏾	men with bunny ears: dark skin tone, medium-dark skin tone	person-activity
👩🏻‍🐰‍👩🏼	women with bunny ears: light skin tone, medium-light skin tone	person-activity
👩🏻‍🐰‍👩🏽	women with bunny ears: light skin tone, medium skin tone	person-activity
👩🏻‍🐰‍👩🏾	women with bunny ears: light skin tone, medium-dark skin tone	person-activity
👩🏻‍🐰‍👩🏿	women with bunny ears: light skin tone, dark skin tone	person-activity
👩🏼‍🐰‍👩🏻	women with bunny ears: medium-light skin tone, light skin tone	person-activity
👩🏼‍🐰‍👩🏽	women with bunny ears: medium-light skin tone, medium skin tone	person-activity
👩🏼‍🐰‍👩🏾	women with bunny ears: medium-light skin tone, medium-dark skin tone	person-activity
👩🏼‍🐰‍👩🏿	women with bunny ears: medium-light skin tone, dark skin tone	person-activity
👩🏽‍🐰‍👩🏻	women with bunny ears: medium skin tone, light skin tone	person-activity
👩🏽‍🐰‍👩🏼	women with bunny ears: medium skin tone, medium-light skin tone	person-activity
👩🏽‍🐰‍👩🏾	women with bunny ears: medium skin tone, medium-dark skin tone	person-activity
👩🏽‍🐰‍👩🏿	women with bunny ears: medium skin tone, dark skin tone	person-activity
👩🏾‍🐰‍👩🏻	women with bunny ears: medium-dark skin tone, light skin tone	person-activity
👩🏾‍🐰‍👩🏼	women with bunny ears: medium-dark skin tone, medium-light skin tone	person-activity
👩🏾‍🐰‍👩🏽	women with bunny ears: medium-dark skin tone, medium skin tone	person-activity
👩🏾‍🐰‍👩🏿	women with bunny ears: medium-dark skin tone, dark skin tone	person-activity
👩🏿‍🐰‍👩🏻	women with bunny ears: dark skin tone, light skin tone	person-activity
👩🏿‍🐰‍👩🏼	women with bunny ears: dark skin tone, medium-light skin tone	person-activity
👩🏿‍🐰‍👩🏽	women with bunny ears: dark skin tone, medium skin tone	person-activity
👩🏿‍🐰‍👩🏾	women with bunny ears: dark skin tone, medium-dark skin tone	person-activity
🧖	person in steamy room	person-activity
🧖🏻	person in steamy room: light skin tone	person-activity
🧖🏼	person in steamy room: medium-light skin tone	person-activity
🧖🏽	person in steamy room: medium skin tone	person-activity
🧖🏾	person in steamy room: medium-dark skin tone	person-activity
🧖🏿	person in steamy room: dark skin tone	person-activity
🧖‍♂️	man in steamy room	person-activity
🧖🏻‍♂️	man in steamy room: light skin tone	person-activity
🧖🏼‍♂️	man in steamy room: medium-light skin tone	person-activity
🧖🏽‍♂️	man in steamy room: medium skin tone	person-activity
🧖🏾‍♂️	man in steamy room: medium-dark skin tone	person-activity
🧖🏿‍♂️	man in steamy room: dark skin tone	person-activity
🧖‍♀️	woman in steamy room	person-activity
🧖🏻‍♀️	woman in steamy room: light skin tone	person-activity
🧖🏼‍♀️	woman in steamy room: medium-light skin tone	person-activity
🧖🏽‍♀️	woman in steamy room: medium skin tone	person-activity
🧖🏾‍♀️	woman in steamy room: medium-dark skin tone	person-activity
🧖🏿‍♀️	woman in steamy room: dark skin tone	person-activity
🧗	person climbing	person-activity
🧗🏻	person climbing: light skin tone	person-activity
🧗🏼	person climbing: medium-light skin tone	person-activity
🧗🏽	person climbing: medium skin tone	person-activity
🧗🏾	person climbing: medium-dark skin tone	person-activity
🧗🏿	person climbing: dark skin tone	person-activity
🧗‍♂️	man climbing	person-activity
🧗🏻‍♂️	man climbing: light skin tone	person-activity
🧗🏼‍♂️	man climbing: medium-light skin tone	person-activity
🧗🏽‍♂️	man climbing: medium skin tone	person-activity
🧗🏾‍♂️	man climbing: medium-dark skin tone	person-activity
🧗🏿‍♂️	man climbing: dark skin tone	person-activity
🧗‍♀️	woman climbing	person-activity
🧗🏻‍♀️	woman climbing: light skin tone	person-activity
🧗🏼‍♀️	woman climbing: medium-light skin tone	person-activity
🧗🏽‍♀️	woman climbing: medium skin tone	person-activity
🧗🏾‍♀️	woman climbing: medium-dark skin tone	person-activity
🧗🏿‍♀️	woman climbing: dark skin tone	person-activity
🤺	person fencing	person-sport
🏇	horse racing	person-sport
🏇🏻	horse racing: light skin tone	person-sport
🏇🏼	horse racing: medium-light skin tone	person-sport
🏇🏽	horse racing: medium skin tone	person-sport
🏇🏾	horse racing: medium-dark skin tone	person-sport
🏇🏿	horse racing: dark skin tone	person-sport
⛷️	skier	person-sport
🏂	snowboarder	person-sport
🏂🏻	snowboarder: light skin tone	person-sport
🏂🏼	snowboarder: medium-light skin tone	person-sport
🏂🏽	snowboarder: medium skin tone	person-sport
🏂🏾	snowboarder: medium-dark skin tone	person-sport
🏂🏿	snowboarder: dark skin tone	person-sport
🏌️	person golfing	person-sport
🏌🏻	person golfing: light skin tone	person-sport
🏌🏼	person golfing: medium-light skin tone	person-sport
🏌🏽	person golfing: medium skin tone	person-sport
🏌🏾	person golfing: medium-dark skin tone	person-sport
🏌🏿	person golfing: dark skin tone	person-sport
🏌️‍♂️	man golfing	person-sport
🏌🏻‍♂️	man golfing: light skin tone	person-sport
🏌🏼‍♂️	man golfing: medium-light skin tone	person-sport
🏌🏽‍♂️	man golfing: medium skin tone	person-sport
🏌🏾‍♂️	man golfing: medium-dark skin tone	person-sport
🏌🏿‍♂️	man golfing: dark skin tone	person-sport
🏌️‍♀️	woman golfing	person-sport
🏌🏻‍♀️	woman golfing: light skin tone	person-sport
🏌🏼‍♀️	woman golfing: medium-light skin tone	person-sport
🏌🏽‍♀️	woman golfing: medium skin tone	person-sport
🏌🏾‍♀️	woman golfing: medium-dark skin tone	person-sport
🏌🏿‍♀️	woman golfing: dark skin tone	person-sport
🏄	person surfing	person-sport
🏄🏻	person surfing: light skin tone	person-sport
🏄🏼	person surfing: medium-light skin tone	person-sport
🏄🏽	person surfing: medium skin tone	person-sport
🏄🏾	person surfing: medium-dark skin tone	person-sport
🏄🏿	person surfing: dark skin tone	person-sport
🏄‍♂️	man surfing	person-sport
🏄🏻‍♂️	man surfing: light skin tone	person-sport
🏄🏼‍♂️	man surfing: medium-light skin tone	person-sport
🏄🏽‍♂️	man surfing: medium skin tone	person-sport
🏄🏾‍♂️	man surfing: medium-dark skin tone	person-sport
🏄🏿‍♂️	man surfing: dark skin tone	person-sport
🏄‍♀️	woman surfing	person-sport
🏄🏻‍♀️	woman surfing: light skin tone	person-sport
🏄🏼‍♀️	woman surfing: medium-light skin tone	person-sport
🏄🏽‍♀️	woman surfing: medium skin tone	person-sport
🏄🏾‍♀️	woman surfing: medium-dark skin tone	person-sport
🏄🏿‍♀️	woman surfing: dark skin tone	person-sport
🚣	person rowing boat	person-sport
🚣🏻	person rowing boat: light skin tone	person-sport
🚣🏼	person rowing boat: medium-light skin tone	person-sport
🚣🏽	person rowing boat: medium skin tone	person-sport
🚣🏾	person rowing boat: medium-dark skin tone	person-sport
🚣🏿	person rowing boat: dark skin tone	person-sport
🚣‍♂️	man rowing boat	person-sport
🚣🏻‍♂️	man rowing boat: light skin tone	person-sport
🚣🏼‍♂️	man rowing boat: medium-light skin tone	person-sport
🚣🏽‍♂️	man rowing boat: medium skin tone	person-sport
🚣🏾‍♂️	man rowing boat: medium-dark skin tone	person-sport
🚣🏿‍♂️	man rowing boat: dark skin tone	person-sport
🚣‍♀️	woman rowing boat	person-sport
🚣🏻‍♀️	woman rowing boat: light skin tone	person-sport
🚣🏼‍♀️	woman rowing boat: medium-light skin tone	person-sport
🚣🏽‍♀️	woman rowing boat: medium skin tone	person-sport
🚣🏾‍♀️	woman rowing boat: medium-dark skin tone	person-sport
🚣🏿‍♀️	woman rowing boat: dark skin tone	person-sport
🏊	person swimming	person-sport
🏊🏻	person swimming: light skin tone	person-sport
🏊🏼	person swimming: medium-light skin tone	person-sport
🏊🏽	person swimming: medium skin tone	person-sport
🏊🏾	person swimming: medium-dark skin tone	person-sport
🏊🏿	person swimming: dark skin tone	person-sport
🏊‍♂️	man swimming	person-sport
🏊🏻‍♂️	man swimming: light skin tone	person-sport
🏊🏼‍♂️	man swimming: medium-light skin tone	person-sport
🏊🏽‍♂️	man swimming: medium skin tone	person-sport
🏊🏾‍♂️	man swimming: medium-dark skin tone	person-sport
🏊🏿‍♂️	man swimming: dark skin tone	person-sport
🏊‍♀️	woman swimming	person-sport
🏊🏻‍♀️	woman swimming: light skin tone	person-sport
🏊🏼‍♀️	woman swimming: medium-light skin tone	person-sport
🏊🏽‍♀️	woman swimming: medium skin tone	person-sport
🏊🏾‍♀️	woman swimming: medium-dark skin tone	person-sport
🏊🏿‍♀️	woman swimming: dark skin tone	person-sport
⛹️	person bouncing ball	person-sport
⛹🏻	person bouncing ball: light skin tone	person-sport
⛹🏼	person bouncing ball: medium-light skin tone	person-sport
⛹🏽	person bouncing ball: medium skin tone	person-sport
⛹🏾	person bouncing ball: medium-dark skin tone	person-sport
⛹🏿	person bouncing ball: dark skin tone	person-sport
⛹️‍♂️	man bouncing ball	person-sport
⛹🏻‍♂️	man bouncing ball: light skin tone	person-sport
⛹🏼‍♂️	man bouncing ball: medium-light skin tone	person-sport
⛹🏽‍♂️	man bouncing ball: medium skin tone	person-sport
⛹🏾‍♂️	man bouncing ball: medium-dark skin tone	person-sport
⛹🏿‍♂️	man bouncing ball: dark skin tone	person-sport
⛹️‍♀️	woman bouncing ball	person-sport
⛹🏻‍♀️	woman bouncing ball: light skin tone	person-sport
⛹🏼‍♀️	woman bouncing ball: medium-light skin tone	person-sport
⛹🏽‍♀️	woman bouncing ball: medium skin tone	person-sport
⛹🏾‍♀️	woman bouncing ball: medium-dark skin tone	person-sport
⛹🏿‍♀️	woman bouncing ball: dark skin tone	person-sport
🏋️	person lifting weights	person-sport
🏋🏻	person lifting weights: light skin tone	person-sport
🏋🏼	person lifting weights: medium-light skin tone	person-sport
🏋🏽	person lifting weights: medium skin tone	person-sport
🏋🏾	person lifting weights: medium-dark skin tone	person-sport
🏋🏿	person lifting weights: dark skin tone	person-sport
🏋️‍♂️	man lifting weights	person-sport
🏋🏻‍♂️	man lifting weights: light skin tone	person-sport
🏋🏼‍♂️	man lifting weights: medium-light skin tone	person-sport
🏋🏽‍♂️	man lifting weights: medium skin tone	person-sport
🏋🏾‍♂️	man lifting weights: medium-dark skin tone	person-sport
🏋🏿‍♂️	man lifting weights: dark skin tone	person-sport
🏋️‍♀️	woman lifting weights	person-sport
🏋🏻‍♀️	woman lifting weights: light skin tone	person-sport
🏋🏼‍♀️	woman lifting weights: medium-light skin tone	person-sport
🏋🏽‍♀️	woman lifting weights: medium skin tone	person-sport
🏋🏾‍♀️	woman lifting weights: medium-dark skin tone	person-sport
🏋🏿‍♀️	woman lifting weights: dark skin tone	person-sport
🚴	person biking	person-sport
🚴🏻	person biking: light skin tone	person-sport
🚴🏼	person biking: medium-light skin tone	person-sport
🚴🏽	person biking: medium skin tone	person-sport
🚴🏾	person biking: medium-dark skin tone	person-sport
🚴🏿	person biking: dark skin tone	person-sport
🚴‍♂️	man biking	person-sport
🚴🏻‍♂️	man biking: light skin tone	person-sport
🚴🏼‍♂️	man biking: medium-light skin tone	person-sport
🚴🏽‍♂️	man biking: medium skin tone	person-sport
🚴🏾‍♂️	man biking: medium-dark skin tone	person-sport
🚴🏿‍♂️	man biking: dark skin tone	person-sport
🚴‍♀️	woman biking	person-sport
🚴🏻‍♀️	woman biking: light skin tone	person-sport
🚴🏼‍♀️	woman biking: medium-light skin tone	person-sport
🚴🏽‍♀️	woman biking: medium skin tone	person-sport
🚴🏾‍♀️	woman biking: medium-dark skin tone	person-sport
🚴🏿‍♀️	woman biking: dark skin tone	person-sport
🚵	person mountain biking	person-sport
🚵🏻	person mountain biking: light skin tone	person-sport
🚵🏼	person mountain biking: medium-light skin tone	person-sport
🚵🏽	person mountain biking: medium skin tone	person-sport
🚵🏾	person mountain biking: medium-dark skin tone	person-sport
🚵🏿	person mountain biking: dark skin tone	person-sport
🚵‍♂️	man mountain biking	person-sport
🚵🏻‍♂️	man mountain biking: light skin tone	person-sport
🚵🏼‍♂️	man mountain biking: medium-light skin tone	person-sport
🚵🏽‍♂️	man mountain biking: medium skin tone	person-sport
🚵🏾‍♂️	man mountain biking: medium-dark skin tone	person-sport
🚵🏿‍♂️	man mountain biking: dark skin tone	person-sport
🚵‍♀️	woman mountain biking	person-sport
🚵🏻‍♀️	woman mountain biking: light skin tone	person-sport
🚵🏼‍♀️	woman mountain biking: medium-light skin tone	person-sport
🚵🏽‍♀️	woman mountain biking: medium skin tone	person-sport
🚵🏾‍♀️	woman mountain biking: medium-dark skin tone	person-sport
🚵🏿‍♀️	woman mountain biking: dark skin tone	person-sport
🤸	person cartwheeling	person-sport
🤸🏻	person cartwheeling: light skin tone	person-sport
🤸🏼	person cartwheeling: medium-light skin tone	person-sport
🤸🏽	person cartwheeling: medium skin tone	person-sport
🤸🏾	person cartwheeling: medium-dark skin tone	person-sport
🤸🏿	person cartwheeling: dark skin tone	person-sport
🤸‍♂️	man cartwheeling	person-sport
🤸🏻‍♂️	man cartwheeling: light skin tone	person-sport
🤸🏼‍♂️	man cartwheeling: medium-light skin tone	person-sport
🤸🏽‍♂️	man cartwheeling: medium skin tone	person-sport
🤸🏾‍♂️	man cartwheeling: medium-dark skin tone	person-sport
🤸🏿‍♂️	man cartwheeling: dark skin tone	person-sport
🤸‍♀️	woman cartwheeling	person-sport
🤸🏻‍♀️	woman cartwheeling: light skin tone	person-sport
🤸🏼‍♀️	woman cartwheeling: medium-light skin tone	person-sport
🤸🏽‍♀️	woman cartwheeling: medium skin tone	person-sport
🤸🏾‍♀️	woman cartwheeling: medium-dark skin tone	person-sport
🤸🏿‍♀️	woman cartwheeling: dark skin tone	person-sport
🤼	people wrestling	person-sport
🤼🏻	people wrestling: light skin tone	person-sport
🤼🏼	people wrestling: medium-light skin tone	person-sport
🤼🏽	people wrestling: medium skin tone	person-sport
🤼🏾	people wrestling: medium-dark skin tone	person-sport
🤼🏿	people wrestling: dark skin tone	person-sport
🤼‍♂️	men wrestling	person-sport
🤼🏻‍♂️	men wrestling: light skin tone	person-sport
🤼🏼‍♂️	men wrestling: medium-light skin tone	person-sport
🤼🏽‍♂️	men wrestling: medium skin tone	person-sport
🤼🏾‍♂️	men wrestling: medium-dark skin tone	person-sport
🤼🏿‍♂️	men wrestling: dark skin tone	person-sport
🤼‍♀️	women wrestling	person-sport
🤼🏻‍♀️	women wrestling: light skin tone	person-sport
🤼🏼‍♀️	women wrestling: medium-light skin tone	person-sport
🤼🏽‍♀️	women wrestling: medium skin tone	person-sport
🤼🏾‍♀️	women wrestling: medium-dark skin tone	person-sport
🤼🏿‍♀️	women wrestling: dark skin tone	person-sport
🧑🏻‍🫯‍🧑🏼	people wrestling: light skin tone, medium-light skin tone	person-sport
🧑🏻‍🫯‍🧑🏽	people wrestling: light skin tone, medium skin tone	person-sport
🧑🏻‍🫯‍🧑🏾	people wrestling: light skin tone, medium-dark skin tone	person-sport
🧑🏻‍🫯‍🧑🏿	people wrestling: light skin tone, dark skin tone	person-sport
🧑🏼‍🫯‍🧑🏻	people wrestling: medium-light skin tone, light skin tone	person-sport
🧑🏼‍🫯‍🧑🏽	people wrestling: medium-light skin tone, medium skin tone	person-sport
🧑🏼‍🫯‍🧑🏾	people wrestling: medium-light skin tone, medium-dark skin tone	person-sport
🧑🏼‍🫯‍🧑🏿	people wrestling: medium-light skin tone, dark skin tone	person-sport
🧑🏽‍🫯‍🧑🏻	people wrestling: medium skin tone, light skin tone	person-sport
🧑🏽‍🫯‍🧑🏼	people wrestling: medium skin tone, medium-light skin tone	person-sport
🧑🏽‍🫯‍🧑🏾	people wrestling: medium skin tone, medium-dark skin tone	person-sport
🧑🏽‍🫯‍🧑🏿	people wrestling: medium skin tone, dark skin tone	person-sport
🧑🏾‍🫯‍🧑🏻	people wrestling: medium-dark skin tone, light skin tone	person-sport
🧑🏾‍🫯‍🧑🏼	people wrestling: medium-dark skin tone, medium-light skin tone	person-sport
🧑🏾‍🫯‍🧑🏽	people wrestling: medium-dark skin tone, medium skin tone	person-sport
🧑🏾‍🫯‍🧑🏿	people wrestling: medium-dark skin tone, dark skin tone	person-sport
🧑🏿‍🫯‍🧑🏻	people wrestling: dark skin tone, light skin tone	person-sport
🧑🏿‍🫯‍🧑🏼	people wrestling: dark skin tone, medium-light skin tone	person-sport
🧑🏿‍🫯‍🧑🏽	people wrestling: dark skin tone, medium skin tone	person-sport
🧑🏿‍🫯‍🧑🏾	people wrestling: dark skin tone, medium-dark skin tone	person-sport
👨🏻‍🫯‍👨🏼	men wrestling: light skin tone, medium-light skin tone	person-sport
👨🏻‍🫯‍👨🏽	men wrestling: light skin tone, medium skin tone	person-sport
👨🏻‍🫯‍👨🏾	men wrestling: light skin tone, medium-dark skin tone	person-sport
👨🏻‍🫯‍👨🏿	men wrestling: light skin tone, dark skin tone	person-sport
👨🏼‍🫯‍👨🏻	men wrestling: medium-light skin tone, light skin tone	person-sport
👨🏼‍🫯‍👨🏽	men wrestling: medium-light skin tone, medium skin tone	person-sport
👨🏼‍🫯‍👨🏾	men wrestling: medium-light skin tone, medium-dark skin tone	person-sport
👨🏼‍🫯‍👨🏿	men wrestling: medium-light skin tone, dark skin tone	person-sport
👨🏽‍🫯‍👨🏻	men wrestling: medium skin tone, light skin tone	person-sport
👨🏽‍🫯‍👨🏼	men wrestling: medium skin tone, medium-light skin tone	person-sport
👨🏽‍🫯‍👨🏾	men wrestling: medium skin tone, medium-dark skin tone	person-sport
👨🏽‍🫯‍👨🏿	men wrestling: medium skin tone, dark skin tone	person-sport
👨🏾‍🫯‍👨🏻	men wrestling: medium-dark skin tone, light skin tone	person-sport
👨🏾‍🫯‍👨🏼	men wrestling: medium-dark skin tone, medium-light skin tone	person-sport
👨🏾‍🫯‍👨🏽	men wrestling: medium-dark skin tone, medium skin tone	person-sport
👨🏾‍🫯‍👨🏿	men wrestling: medium-dark skin tone, dark skin tone	person-sport
👨🏿‍🫯‍👨🏻	men wrestling: dark skin tone, light skin tone	person-sport
👨🏿‍🫯‍👨🏼	men wrestling: dark skin tone, medium-light skin tone	person-sport
👨🏿‍🫯‍👨🏽	men wrestling: dark skin tone, medium skin tone	person-sport
👨🏿‍🫯‍👨🏾	men wrestling: dark skin tone, medium-dark skin tone	person-sport
👩🏻‍🫯‍👩🏼	women wrestling: light skin tone, medium-light skin tone	person-sport
👩🏻‍🫯‍👩🏽	women wrestling: light skin tone, medium skin tone	person-sport
👩🏻‍🫯‍👩🏾	women wrestling: light skin tone, medium-dark skin tone	person-sport
👩🏻‍🫯‍👩🏿	women wrestling: light skin tone, dark skin tone	person-sport
👩🏼‍🫯‍👩🏻	women wrestling: medium-light skin tone, light skin tone	person-sport
👩🏼‍🫯‍👩🏽	women wrestling: medium-light skin tone, medium skin tone	person-sport
👩🏼‍🫯‍👩🏾	women wrestling: medium-light skin tone, medium-dark skin tone	person-sport
👩🏼‍🫯‍👩🏿	women wrestling: medium-light skin tone, dark skin tone	person-sport
👩🏽‍🫯‍👩🏻	women wrestling: medium skin tone, light skin tone	person-sport
👩🏽‍🫯‍👩🏼	women wrestling: medium skin tone, medium-light skin tone	person-sport
👩🏽‍🫯‍👩🏾	women wrestling: medium skin tone, medium-dark skin tone	person-sport
👩🏽‍🫯‍👩🏿	women wrestling: medium skin tone, dark skin tone	person-sport
👩🏾‍🫯‍👩🏻	women wrestling: medium-dark skin tone, light skin tone	person-sport
👩🏾‍🫯‍👩🏼	women wrestling: medium-dark skin tone, medium-light skin tone	person-sport
👩🏾‍🫯‍👩🏽	women wrestling: medium-dark skin tone, medium skin tone	person-sport
👩🏾‍🫯‍👩🏿	women wrestling: medium-dark skin tone, dark skin tone	person-sport
👩🏿‍🫯‍👩🏻	women wrestling: dark skin tone, light skin tone	person-sport
👩🏿‍🫯‍👩🏼	women wrestling: dark skin tone, medium-light skin tone	person-sport
👩🏿‍🫯‍👩🏽	women wrestling: dark skin tone, medium skin tone	person-sport
👩🏿‍🫯‍👩🏾	women wrestling: dark skin tone, medium-dark skin tone	person-sport
🤽	person playing water polo	person-sport
🤽🏻	person playing water polo: light skin tone	person-sport
🤽🏼	person playing water polo: medium-light skin tone	person-sport
🤽🏽	person playing water polo: medium skin tone	person-sport
🤽🏾	person playing water polo: medium-dark skin tone	person-sport
🤽🏿	person playing water polo: dark skin tone	person-sport
🤽‍♂️	man playing water polo	person-sport
🤽🏻‍♂️	man playing water polo: light skin tone	person-sport
🤽🏼‍♂️	man playing water polo: medium-light skin tone	person-sport
🤽🏽‍♂️	man playing water polo: medium skin tone	person-sport
🤽🏾‍♂️	man playing water polo: medium-dark skin tone	person-sport
🤽🏿‍♂️	man playing water polo: dark skin tone	person-sport
🤽‍♀️	woman playing water polo	person-sport
🤽🏻‍♀️	woman playing water polo: light skin tone	person-sport
🤽🏼‍♀️	woman playing water polo: medium-light skin tone	person-sport
🤽🏽‍♀️	woman playing water polo: medium skin tone	person-sport
🤽🏾‍♀️	woman playing water polo: medium-dark skin tone	person-sport
🤽🏿‍♀️	woman playing water polo: dark skin tone	person-sport
🤾	person playing handball	person-sport
🤾🏻	person playing handball: light skin tone	person-sport
🤾🏼	person playing handball: medium-light skin tone	person-sport
🤾🏽	person playing handball: medium skin tone	person-sport
🤾🏾	person playing handball: medium-dark skin tone	person-sport
🤾🏿	person playing handball: dark skin tone	person-sport
🤾‍♂️	man playing handball	person-sport
🤾🏻‍♂️	man playing handball: light skin tone	person-sport
🤾🏼‍♂️	man playing handball: medium-light skin tone	person-sport
🤾🏽‍♂️	man playing handball: medium skin tone	person-sport
🤾🏾‍♂️	man playing handball: medium-dark skin tone	person-sport
🤾🏿‍♂️	man playing handball: dark skin tone	person-sport
🤾‍♀️	woman playing handball	person-sport
🤾🏻‍♀️	woman playing handball: light skin tone	person-sport
🤾🏼‍♀️	woman playing handball: medium-light skin tone	person-sport
🤾🏽‍♀️	woman playing handball: medium skin tone	person-sport
🤾🏾‍♀️	woman playing handball: medium-dark skin tone	person-sport
🤾🏿‍♀️	woman playing handball: dark skin tone	person-sport
🤹	person juggling	person-sport
🤹🏻	person juggling: light skin tone	person-sport
🤹🏼	person juggling: medium-light skin tone	person-sport
🤹🏽	person juggling: medium skin tone	person-sport
🤹🏾	person juggling: medium-dark skin tone	person-sport
🤹🏿	person juggling: dark skin tone	person-sport
🤹‍♂️	man juggling	person-sport
🤹🏻‍♂️	man juggling: light skin tone	person-sport
🤹🏼‍♂️	man juggling: medium-light skin tone	person-sport
🤹🏽‍♂️	man juggling: medium skin tone	person-sport
🤹🏾‍♂️	man juggling: medium-dark skin tone	person-sport
🤹🏿‍♂️	man juggling: dark skin tone	person-sport
🤹‍♀️	woman juggling	person-sport
🤹🏻‍♀️	woman juggling: light skin tone	person-sport
🤹🏼‍♀️	woman juggling: medium-light skin tone	person-sport
🤹🏽‍♀️	woman juggling: medium skin tone	person-sport
🤹🏾‍♀️	woman juggling: medium-dark skin tone	person-sport
🤹🏿‍♀️	woman juggling: dark skin tone	person-sport
🧘	person in lotus position	person-resting
🧘🏻	person in lotus position: light skin tone	person-resting
🧘🏼	person in lotus position: medium-light skin tone	person-resting
🧘🏽	person in lotus position: medium skin tone	person-resting
🧘🏾	person in lotus position: medium-dark skin tone	person-resting
🧘🏿	person in lotus position: dark skin tone	person-resting
🧘‍♂️	man in lotus position	person-resting
🧘🏻‍♂️	man in lotus position: light skin tone	person-resting
🧘🏼‍♂️	man in lotus position: medium-light skin tone	person-resting
🧘🏽‍♂️	man in lotus position: medium skin tone	person-resting
🧘🏾‍♂️	man in lotus position: medium-dark skin tone	person-resting
🧘🏿‍♂️	man in lotus position: dark skin tone	person-resting
🧘‍♀️	woman in lotus position	person-resting
🧘🏻‍♀️	woman in lotus position: light skin tone	person-resting
🧘🏼‍♀️	woman in lotus position: medium-light skin tone	person-resting
🧘🏽‍♀️	woman in lotus position: medium skin tone	person-resting
🧘🏾‍♀️	woman in lotus position: medium-dark skin tone	person-resting
🧘🏿‍♀️	woman in lotus position: dark skin tone	person-resting
🛀	person taking bath	person-resting
🛀🏻	person taking bath: light skin tone	person-resting
🛀🏼	person taking bath: medium-light skin tone	person-resting
🛀🏽	person taking bath: medium skin tone	person-resting
🛀🏾	person taking bath: medium-dark skin tone	person-resting
🛀🏿	person taking bath: dark skin tone	person-resting
🛌	person in bed	person-resting
🛌🏻	person in bed: light skin tone	person-resting
🛌🏼	person in bed: medium-light skin tone	person-resting
🛌🏽	person in bed: medium skin tone	person-resting
🛌🏾	person in bed: medium-dark skin tone	person-resting
🛌🏿	person in bed: dark skin tone	person-resting
🧑‍🤝‍🧑	people holding hands	family
🧑🏻‍🤝‍🧑🏻	people holding hands: light skin tone	family
🧑🏻‍🤝‍🧑🏼	people holding hands: light skin tone, medium-light skin tone	family
🧑🏻‍🤝‍🧑🏽	people holding hands: light skin tone, medium skin tone	family
🧑🏻‍🤝‍🧑🏾	people holding hands: light skin tone, medium-dark skin tone	family
🧑🏻‍🤝‍🧑🏿	people holding hands: light skin tone, dark skin tone	family
🧑🏼‍🤝‍🧑🏻	people holding hands: medium-light skin tone, light skin tone	family
🧑🏼‍🤝‍🧑🏼	people holding hands: medium-light skin tone	family
🧑🏼‍🤝‍🧑🏽	people holding hands: medium-light skin tone, medium skin tone	family
🧑🏼‍🤝‍🧑🏾	people holding hands: medium-light skin tone, medium-dark skin tone	family
🧑🏼‍🤝‍🧑🏿	people holding hands: medium-light skin tone, dark skin tone	family
🧑🏽‍🤝‍🧑🏻	people holding hands: medium skin tone, light skin tone	family
🧑🏽‍🤝‍🧑🏼	people holding hands: medium skin tone, medium-light skin tone	family
🧑🏽‍🤝‍🧑🏽	people holding hands: medium skin tone	family
🧑🏽‍🤝‍🧑🏾	people holding hands: medium skin tone, medium-dark skin tone	family
🧑🏽‍🤝‍🧑🏿	people holding hands: medium skin tone, dark skin tone	family
🧑🏾‍🤝‍🧑🏻	people holding hands: medium-dark skin tone, light skin tone	family
🧑🏾‍🤝‍🧑🏼	people holding hands: medium-dark skin tone, medium-light skin tone	family
🧑🏾‍🤝‍🧑🏽	people holding hands: medium-dark skin tone, medium skin tone	family
🧑🏾‍🤝‍🧑🏾	people holding hands: medium-dark skin tone	family
🧑🏾‍🤝‍🧑🏿	people holding hands: medium-dark skin tone, dark skin tone	family
🧑🏿‍🤝‍🧑🏻	people holding hands: dark skin tone, light skin tone	family
🧑🏿‍🤝‍🧑🏼	people holding hands: dark skin tone, medium-light skin tone	family
🧑🏿‍🤝‍🧑🏽	people holding hands: dark skin tone, medium skin tone	family
🧑🏿‍🤝‍🧑🏾	people holding hands: dark skin tone, medium-dark skin tone	family
🧑🏿‍🤝‍🧑🏿	people holding hands: dark skin tone	family
👭	women holding hands	family
👭🏻	women holding hands: light skin tone	family
👩🏻‍🤝‍👩🏼	women holding hands: light skin tone, medium-light skin tone	family
👩🏻‍🤝‍👩🏽	women holding hands: light skin tone, medium skin tone	family
👩🏻‍🤝‍👩🏾	women holding hands: light skin tone, medium-dark skin tone	family
👩🏻‍🤝‍👩🏿	women holding hands: light skin tone, dark skin tone	family
👩🏼‍🤝‍👩🏻	women holding hands: medium-light skin tone, light skin tone	family
👭🏼	women holding hands: medium-light skin tone	family
👩🏼‍🤝‍👩🏽	women holding hands: medium-light skin tone, medium skin tone	family
👩🏼‍🤝‍👩🏾	women holding hands: medium-light skin tone, medium-dark skin tone	family
👩🏼‍🤝‍👩🏿	women holding hands: medium-light skin tone, dark skin tone	family
👩🏽‍🤝‍👩🏻	women holding hands: medium skin tone, light skin tone	family
👩🏽‍🤝‍👩🏼	women holding hands: medium skin tone, medium-light skin tone	family
👭🏽	women holding hands: medium skin tone	family
👩🏽‍🤝‍👩🏾	women holding hands: medium skin tone, medium-dark skin tone	family
👩🏽‍🤝‍👩🏿	women holding hands: medium skin tone, dark skin tone	family
👩🏾‍🤝‍👩🏻	women holding hands: medium-dark skin tone, light skin tone	family
👩🏾‍🤝‍👩🏼	women holding hands: medium-dark skin tone, medium-light skin tone	family
👩🏾‍🤝‍👩🏽	women holding hands: medium-dark skin tone, medium skin tone	family
👭🏾	women holding hands: medium-dark skin tone	family
👩🏾‍🤝‍👩🏿	women holding hands: medium-dark skin tone, dark skin tone	family
👩🏿‍🤝‍👩🏻	women holding hands: dark skin tone, light skin tone	family
👩🏿‍🤝‍👩🏼	women holding hands: dark skin tone, medium-light skin tone	family
👩🏿‍🤝‍👩🏽	women holding hands: dark skin tone, medium skin tone	family
👩🏿‍🤝‍👩🏾	women holding hands: dark skin tone, medium-dark skin tone	family
👭🏿	women holding hands: dark skin tone	family
👫	woman and man holding hands	family
👫🏻	woman and man holding hands: light skin tone	family
👩🏻‍🤝‍👨🏼	woman and man holding hands: light skin tone, medium-light skin tone	family
👩🏻‍🤝‍👨🏽	woman and man holding hands: light skin tone, medium skin tone	family
👩🏻‍🤝‍👨🏾	woman and man holding hands: light skin tone, medium-dark skin tone	family
👩🏻‍🤝‍👨🏿	woman and man holding hands: light skin tone, dark skin tone	family
👩🏼‍🤝‍👨🏻	woman and man holding hands: medium-light skin tone, light skin tone	family
👫🏼	woman and man holding hands: medium-light skin tone	family
👩🏼‍🤝‍👨🏽	woman and man holding hands: medium-light skin tone, medium skin tone	family
👩🏼‍🤝‍👨🏾	woman and man holding hands: medium-light skin tone, medium-dark skin tone	family
👩🏼‍🤝‍👨🏿	woman and man holding hands: medium-light skin tone, dark skin tone	family
👩🏽‍🤝‍👨🏻	woman and man holding hands: medium skin tone, light skin tone	family
👩🏽‍🤝‍👨🏼	woman and man holding hands: medium skin tone, medium-light skin tone	family
👫🏽	woman and man holding hands: medium skin tone	family
👩🏽‍🤝‍👨🏾	woman and man holding hands: medium skin tone, medium-dark skin tone	family
👩🏽‍🤝‍👨🏿	woman and man holding hands: medium skin tone, dark skin tone	family
👩🏾‍🤝‍👨🏻	woman and man holding hands: medium-dark skin tone, light skin tone	family
👩🏾‍🤝‍👨🏼	woman and man holding hands: medium-dark skin tone, medium-light skin tone	family
👩🏾‍🤝‍👨🏽	woman and man holding hands: medium-dark skin tone, medium skin tone	family
👫🏾	woman and man holding hands: medium-dark skin tone	family
👩🏾‍🤝‍👨🏿	woman and man holding hands: medium-dark skin tone, dark skin tone	family
👩🏿‍🤝‍👨🏻	woman and man holding hands: dark skin tone, light skin tone	family
👩🏿‍🤝‍👨🏼	woman and man holding hands: dark skin tone, medium-light skin tone	family
👩🏿‍🤝‍👨🏽	woman and man holding hands: dark skin tone, medium skin tone	family
👩🏿‍🤝‍👨🏾	woman and man holding hands: dark skin tone, medium-dark skin tone	family
👫🏿	woman and man holding hands: dark skin tone	family
👬	men holding hands	family
👬🏻	men holding hands: light skin tone	family
👨🏻‍🤝‍👨🏼	men holding hands: light skin tone, medium-light skin tone	family
👨🏻‍🤝‍👨🏽	men holding hands: light skin tone, medium skin tone	family
👨🏻‍🤝‍👨🏾	men holding hands: light skin tone, medium-dark skin tone	family
👨🏻‍🤝‍👨🏿	men holding hands: light skin tone, dark skin tone	family
👨🏼‍🤝‍👨🏻	men holding hands: medium-light skin tone, light skin tone	family
👬🏼	men holding hands: medium-light skin tone	family
👨🏼‍🤝‍👨🏽	men holding hands: medium-light skin tone, medium skin tone	family
👨🏼‍🤝‍👨🏾	men holding hands: medium-light skin tone, medium-dark skin tone	family
👨🏼‍🤝‍👨🏿	men holding hands: medium-light skin tone, dark skin tone	family
👨🏽‍🤝‍👨🏻	men holding hands: medium skin tone, light skin tone	family
👨🏽‍🤝‍👨🏼	men holding hands: medium skin tone, medium-light skin tone	family
👬🏽	men holding hands: medium skin tone	family
👨🏽‍🤝‍👨🏾	men holding hands: medium skin tone, medium-dark skin tone	family
👨🏽‍🤝‍👨🏿	men holding hands: medium skin tone, dark skin tone	family
👨🏾‍🤝‍👨🏻	men holding hands: medium-dark skin tone, light skin tone	family
👨🏾‍🤝‍👨🏼	men holding hands: medium-dark skin tone, medium-light skin tone	family
👨🏾‍🤝‍👨🏽	men holding hands: medium-dark skin tone, medium skin tone	family
👬🏾	men holding hands: medium-dark skin tone	family
👨🏾‍🤝‍👨🏿	men holding hands: medium-dark skin tone, dark skin tone	family
👨🏿‍🤝‍👨🏻	men holding hands: dark skin tone, light skin tone	family
👨🏿‍🤝‍👨🏼	men holding hands: dark skin tone, medium-light skin tone	family
👨🏿‍🤝‍👨🏽	men holding hands: dark skin tone, medium skin tone	family
👨🏿‍🤝‍👨🏾	men holding hands: dark skin tone, medium-dark skin tone	family
👬🏿	men holding hands: dark skin tone	family
💏	kiss	family
💏🏻	kiss: light skin tone	family
💏🏼	kiss: medium-light skin tone	family
💏🏽	kiss: medium skin tone	family
💏🏾	kiss: medium-dark skin tone	family
💏🏿	kiss: dark skin tone	family
🧑🏻‍❤️‍💋‍🧑🏼	kiss: person, person, light skin tone, medium-light skin tone	family
🧑🏻‍❤️‍💋‍🧑🏽	kiss: person, person, light skin tone, medium skin tone	family
🧑🏻‍❤️‍💋‍🧑🏾	kiss: person, person, light skin tone, medium-dark skin tone	family
🧑🏻‍❤️‍💋‍🧑🏿	kiss: person, person, light skin tone, dark skin tone	family
🧑🏼‍❤️‍💋‍🧑🏻	kiss: person, person, medium-light skin tone, light skin tone	family
🧑🏼‍❤️‍💋‍🧑🏽	kiss: person, person, medium-light skin tone, medium skin tone	family
🧑🏼‍❤️‍💋‍🧑🏾	kiss: person, person, medium-light skin tone, medium-dark skin tone	family
🧑🏼‍❤️‍💋‍🧑🏿	kiss: person, person, medium-light skin tone, dark skin tone	family
🧑🏽‍❤️‍💋‍🧑🏻	kiss: person, person, medium skin tone, light skin tone	family
🧑🏽‍❤️‍💋‍🧑🏼	kiss: person, person, medium skin tone, medium-light skin tone	family
🧑🏽‍❤️‍💋‍🧑🏾	kiss: person, person, medium skin tone, medium-dark skin tone	family
🧑🏽‍❤️‍💋‍🧑🏿	kiss: person, person, medium skin tone, dark skin tone	family
🧑🏾‍❤️‍💋‍🧑🏻	kiss: person, person, medium-dark skin tone, light skin tone	family
🧑🏾‍❤️‍💋‍🧑🏼	kiss: person, person, medium-dark skin tone, medium-light skin tone	family
🧑🏾‍❤️‍💋‍🧑🏽	kiss: person, person, medium-dark skin tone, medium skin tone	family
🧑🏾‍❤️‍💋‍🧑🏿	kiss: person, person, medium-dark skin tone, dark skin tone	family
🧑🏿‍❤️‍💋‍🧑🏻	kiss: person, person, dark skin tone, light skin tone	family
🧑🏿‍❤️‍💋‍🧑🏼	kiss: person, person, dark skin tone, medium-light skin tone	family
🧑🏿‍❤️‍💋‍🧑🏽	kiss: person, person, dark skin tone, medium skin tone	family
🧑🏿‍❤️‍💋‍🧑🏾	kiss: person, person, dark skin tone, medium-dark skin tone	family
👩‍❤️‍💋‍👨	kiss: woman, man	family
👩🏻‍❤️‍💋‍👨🏻	kiss: woman, man, light skin tone	family
👩🏻‍❤️‍💋‍👨🏼	kiss: woman, man, light skin tone, medium-light skin tone	family
👩🏻‍❤️‍💋‍👨🏽	kiss: woman, man, light skin tone, medium skin tone	family
👩🏻‍❤️‍💋‍👨🏾	kiss: woman, man, light skin tone, medium-dark skin tone	family
👩🏻‍❤️‍💋‍👨🏿	kiss: woman, man, light skin tone, dark skin tone	family
👩🏼‍❤️‍💋‍👨🏻	kiss: woman, man, medium-light skin tone, light skin tone	family
👩🏼‍❤️‍💋‍👨🏼	kiss: woman, man, medium-light skin tone	family
👩🏼‍❤️‍💋‍👨🏽	kiss: woman, man, medium-light skin tone, medium skin tone	family
👩🏼‍❤️‍💋‍👨🏾	kiss: woman, man, medium-light skin tone, medium-dark skin tone	family
👩🏼‍❤️‍💋‍👨🏿	kiss: woman, man, medium-light skin tone, dark skin tone	family
👩🏽‍❤️‍💋‍👨🏻	kiss: woman, man, medium skin tone, light skin tone	family
👩🏽‍❤️‍💋‍👨🏼	kiss: woman, man, medium skin tone, medium-light skin tone	family
👩🏽‍❤️‍💋‍👨🏽	kiss: woman, man, medium skin tone	family
👩🏽‍❤️‍💋‍👨🏾	kiss: woman, man, medium skin tone, medium-dark skin tone	family
👩🏽‍❤️‍💋‍👨🏿	kiss: woman, man, medium skin tone, dark skin tone	family
👩🏾‍❤️‍💋‍👨🏻	kiss: woman, man, medium-dark skin tone, light skin tone	family
👩🏾‍❤️‍💋‍👨🏼	kiss: woman, man, medium-dark skin tone, medium-light skin tone	family
👩🏾‍❤️‍💋‍👨🏽	kiss: woman, man, medium-dark skin tone, medium skin tone	family
👩🏾‍❤️‍💋‍👨🏾	kiss: woman, man, medium-dark skin tone	family
👩🏾‍❤️‍💋‍👨🏿	kiss: woman, man, medium-dark skin tone, dark skin tone	family
👩🏿‍❤️‍💋‍👨🏻	kiss: woman, man, dark skin tone, light skin tone	family
👩🏿‍❤️‍💋‍👨🏼	kiss: woman, man, dark skin tone, medium-light skin tone	family
👩🏿‍❤️‍💋‍👨🏽	kiss: woman, man, dark skin tone, medium skin tone	family
👩🏿‍❤️‍💋‍👨🏾	kiss: woman, man, dark skin tone, medium-dark skin tone	family
👩🏿‍❤️‍💋‍👨🏿	kiss: woman, man, dark skin tone	family
👨‍❤️‍💋‍👨	kiss: man, man	family
👨🏻‍❤️‍💋‍👨🏻	kiss: man, man, light skin tone	family
👨🏻‍❤️‍💋‍👨🏼	kiss: man, man, light skin tone, medium-light skin tone	family
👨🏻‍❤️‍💋‍👨🏽	kiss: man, man, light skin tone, medium skin tone	family
👨🏻‍❤️‍💋‍👨🏾	kiss: man, man, light skin tone, medium-dark skin tone	family
👨🏻‍❤️‍💋‍👨🏿	kiss: man, man, light skin tone, dark skin tone	family
👨🏼‍❤️‍💋‍👨🏻	kiss: man, man, medium-light skin tone, light skin tone	family
👨🏼‍❤️‍💋‍👨🏼	kiss: man, man, medium-light skin tone	family
👨🏼‍❤️‍💋‍👨🏽	kiss: man, man, medium-light skin tone, medium skin tone	family
👨🏼‍❤️‍💋‍👨🏾	kiss: man, man, medium-light skin tone, medium-dark skin tone	family
👨🏼‍❤️‍💋‍👨🏿	kiss: man, man, medium-light skin tone, dark skin tone	family
👨🏽‍❤️‍💋‍👨🏻	kiss: man, man, medium skin tone, light skin tone	family
👨🏽‍❤️‍💋‍👨🏼	kiss: man, man, medium skin tone, medium-light skin tone	family
👨🏽‍❤️‍💋‍👨🏽	kiss: man, man, medium skin tone	family
👨🏽‍❤️‍💋‍👨🏾	kiss: man, man, medium skin tone, medium-dark skin tone	family
👨🏽‍❤️‍💋‍👨🏿	kiss: man, man, medium skin tone, dark skin tone	family
👨🏾‍❤️‍💋‍👨🏻	kiss: man, man, medium-dark skin tone, light skin tone	family
👨🏾‍❤️‍💋‍👨🏼	kiss: man, man, medium-dark skin tone, medium-light skin tone	family
👨🏾‍❤️‍💋‍👨🏽	kiss: man, man, medium-dark skin tone, medium skin tone	family
👨🏾‍❤️‍💋‍👨🏾	kiss: man, man, medium-dark skin tone	family
👨🏾‍❤️‍💋‍👨🏿	kiss: man, man, medium-dark skin tone, dark skin tone	family
👨🏿‍❤️‍💋‍👨🏻	kiss: man, man, dark skin tone, light skin tone	family
👨🏿‍❤️‍💋‍👨🏼	kiss: man, man, dark skin tone, medium-light skin tone	family
👨🏿‍❤️‍💋‍👨🏽	kiss: man, man, dark skin tone, medium skin tone	family
👨🏿‍❤️‍💋‍👨🏾	kiss: man, man, dark skin tone, medium-dark skin tone	family
👨🏿‍❤️‍💋‍👨🏿	kiss: man, man, dark skin tone	family
👩‍❤️‍💋‍👩	kiss: woman, woman	family
👩🏻‍❤️‍💋‍👩🏻	kiss: woman, woman, light skin tone	family
👩🏻‍❤️‍💋‍👩🏼	kiss: woman, woman, light skin tone, medium-light skin tone	family
👩🏻‍❤️‍💋‍👩🏽	kiss: woman, woman, light skin tone, medium skin tone	family
👩🏻‍❤️‍💋‍👩🏾	kiss: woman, woman, light skin tone, medium-dark skin tone	family
👩🏻‍❤️‍💋‍👩🏿	kiss: woman, woman, light skin tone, dark skin tone	family
👩🏼‍❤️‍💋‍👩🏻	kiss: woman, woman, medium-light skin tone, light skin tone	family
👩🏼‍❤️‍💋‍👩🏼	kiss: woman, woman, medium-light skin tone	family
👩🏼‍❤️‍💋‍👩🏽	kiss: woman, woman, medium-light skin tone, medium skin tone	family
👩🏼‍❤️‍💋‍👩🏾	kiss: woman, woman, medium-light skin tone, medium-dark skin tone	family
👩🏼‍❤️‍💋‍👩🏿	kiss: woman, woman, medium-light skin tone, dark skin tone	family
👩🏽‍❤️‍💋‍👩🏻	kiss: woman, woman, medium skin tone, light skin tone	family
👩🏽‍❤️‍💋‍👩🏼	kiss: woman, woman, medium skin tone, medium-light skin tone	family
👩🏽‍❤️‍💋‍👩🏽	kiss: woman, woman, medium skin tone	family
👩🏽‍❤️‍💋‍👩🏾	kiss: woman, woman, medium skin tone, medium-dark skin tone	family
👩🏽‍❤️‍💋‍👩🏿	kiss: woman, woman, medium skin tone, dark skin tone	family
👩🏾‍❤️‍💋‍👩🏻	kiss: woman, woman, medium-dark skin tone, light skin tone	family
👩🏾‍❤️‍💋‍👩🏼	kiss: woman, woman, medium-dark skin tone, medium-light skin tone	family
👩🏾‍❤️‍💋‍👩🏽	kiss: woman, woman, medium-dark skin tone, medium skin tone	family
👩🏾‍❤️‍💋‍👩🏾	kiss: woman, woman, medium-dark skin tone	family
👩🏾‍❤️‍💋‍👩🏿	kiss: woman, woman, medium-dark skin tone, dark skin tone	family
👩🏿‍❤️‍💋‍👩🏻	kiss: woman, woman, dark skin tone, light skin tone	family
👩🏿‍❤️‍💋‍👩🏼	kiss: woman, woman, dark skin tone, medium-light skin tone	family
👩🏿‍❤️‍💋‍👩🏽	kiss: woman, woman, dark skin tone, medium skin tone	family
👩🏿‍❤️‍💋‍👩🏾	kiss: woman, woman, dark skin tone, medium-dark skin tone	family
👩🏿‍❤️‍💋‍👩🏿	kiss: woman, woman, dark skin tone	family
💑	couple with heart	family
💑🏻	couple with heart: light skin tone	family
💑🏼	couple with heart: medium-light skin tone	family
💑🏽	couple with heart: medium skin tone	family
💑🏾	couple with heart: medium-dark skin tone	family
💑🏿	couple with heart: dark skin tone	family
🧑🏻‍❤️‍🧑🏼	couple with heart: person, person, light skin tone, medium-light skin tone	family
🧑🏻‍❤️‍🧑🏽	couple with heart: person, person, light skin tone, medium skin tone	family
🧑🏻‍❤️‍🧑🏾	couple with heart: person, person, light skin tone, medium-dark skin tone	family
🧑🏻‍❤️‍🧑🏿	couple with heart: person, person, light skin tone, dark skin tone	family
🧑🏼‍❤️‍🧑🏻	couple with heart: person, person, medium-light skin tone, light skin tone	family
🧑🏼‍❤️‍🧑🏽	couple with heart: person, person, medium-light skin tone, medium skin tone	family
🧑🏼‍❤️‍🧑🏾	couple with heart: person, person, medium-light skin tone, medium-dark skin tone	family
🧑🏼‍❤️‍🧑🏿	couple with heart: person, person, medium-light skin tone, dark skin tone	family
🧑🏽‍❤️‍🧑🏻	couple with heart: person, person, medium skin tone, light skin tone	family
🧑🏽‍❤️‍🧑🏼	couple with heart: person, person, medium skin tone, medium-light skin tone	family
🧑🏽‍❤️‍🧑🏾	couple with heart: person, person, medium skin tone, medium-dark skin tone	family
🧑🏽‍❤️‍🧑🏿	couple with heart: person, person, medium skin tone, dark skin tone	family
🧑🏾‍❤️‍🧑🏻	couple with heart: person, person, medium-dark skin tone, light skin tone	family
🧑🏾‍❤️‍🧑🏼	couple with heart: person, person, medium-dark skin tone, medium-light skin tone	family
🧑🏾‍❤️‍🧑🏽	couple with heart: person, person, medium-dark skin tone, medium skin tone	family
🧑🏾‍❤️‍🧑🏿	couple with heart: person, person, medium-dark skin tone, dark skin tone	family
🧑🏿‍❤️‍🧑🏻	couple with heart: person, person, dark skin tone, light skin tone	family
🧑🏿‍❤️‍🧑🏼	couple with heart: person, person, dark skin tone, medium-light skin tone	family
🧑🏿‍❤️‍🧑🏽	couple with heart: person, person, dark skin tone, medium skin tone	family
🧑🏿‍❤️‍🧑🏾	couple with heart: person, person, dark skin tone, medium-dark skin tone	family
👩‍❤️‍👨	couple with heart: woman, man	family
👩🏻‍❤️‍👨🏻	couple with heart: woman, man, light skin tone	family
👩🏻‍❤️‍👨🏼	couple with heart: woman, man, light skin tone, medium-light skin tone	family
👩🏻‍❤️‍👨🏽	couple with heart: woman, man, light skin tone, medium skin tone	family
👩🏻‍❤️‍👨🏾	couple with heart: woman, man, light skin tone, medium-dark skin tone	family
👩🏻‍❤️‍👨🏿	couple with heart: woman, man, light skin tone, dark skin tone	family
👩🏼‍❤️‍👨🏻	couple with heart: woman, man, medium-light skin tone, light skin tone	family
👩🏼‍❤️‍👨🏼	couple with heart: woman, man, medium-light skin tone	family
👩🏼‍❤️‍👨🏽	couple with heart: woman, man, medium-light skin tone, medium skin tone	family
👩🏼‍❤️‍👨🏾	couple with heart: woman, man, medium-light skin tone, medium-dark skin tone	family
👩🏼‍❤️‍👨🏿	couple with heart: woman, man, medium-light skin tone, dark skin tone	family
👩🏽‍❤️‍👨🏻	couple with heart: woman, man, medium skin tone, light skin tone	family
👩🏽‍❤️‍👨🏼	couple with heart: woman, man, medium skin tone, medium-light skin tone	family
👩🏽‍❤️‍👨🏽	couple with heart: woman, man, medium skin tone	family
👩🏽‍❤️‍👨🏾	couple with heart: woman, man, medium skin tone, medium-dark skin tone	family
👩🏽‍❤️‍👨🏿	couple with heart: woman, man, medium skin tone, dark skin tone	family
👩🏾‍❤️‍👨🏻	couple with heart: woman, man, medium-dark skin tone, light skin tone	family
👩🏾‍❤️‍👨🏼	couple with heart: woman, man, medium-dark skin tone, medium-light skin tone	family
👩🏾‍❤️‍👨🏽	couple with heart: woman, man, medium-dark skin tone, medium skin tone	family
👩🏾‍❤️‍👨🏾	couple with heart: woman, man, medium-dark skin tone	family
👩🏾‍❤️‍👨🏿	couple with heart: woman, man, medium-dark skin tone, dark skin tone	family
👩🏿‍❤️‍👨🏻	couple with heart: woman, man, dark skin tone, light skin tone	family
👩🏿‍❤️‍👨🏼	couple with heart: woman, man, dark skin tone, medium-light skin tone	family
👩🏿‍❤️‍👨🏽	couple with heart: woman, man, dark skin tone, medium skin tone	family
👩🏿‍❤️‍👨🏾	couple with heart: woman, man, dark skin tone, medium-dark skin tone	family
👩🏿‍❤️‍👨🏿	couple with heart: woman, man, dark skin tone	family
👨‍❤️‍👨	couple with heart: man, man	family
👨🏻‍❤️‍👨🏻	couple with heart: man, man, light skin tone	family
👨🏻‍❤️‍👨🏼	couple with heart: man, man, light skin tone, medium-light skin tone	family
👨🏻‍❤️‍👨🏽	couple with heart: man, man, light skin tone, medium skin tone	family
👨🏻‍❤️‍👨🏾	couple with heart: man, man, light skin tone, medium-dark skin tone	family
👨🏻‍❤️‍👨🏿	couple with heart: man, man, light skin tone, dark skin tone	family
👨🏼‍❤️‍👨🏻	couple with heart: man, man, medium-light skin tone, light skin tone	family
👨🏼‍❤️‍👨🏼	couple with heart: man, man, medium-light skin tone	family
👨🏼‍❤️‍👨🏽	couple with heart: man, man, medium-light skin tone, medium skin tone	family
👨🏼‍❤️‍👨🏾	couple with heart: man, man, medium-light skin tone, medium-dark skin tone	family
👨🏼‍❤️‍👨🏿	couple with heart: man, man, medium-light skin tone, dark skin tone	family
👨🏽‍❤️‍👨🏻	couple with heart: man, man, medium skin tone, light skin tone	family
👨🏽‍❤️‍👨🏼	couple with heart: man, man, medium skin tone, medium-light skin tone	family
👨🏽‍❤️‍👨🏽	couple with heart: man, man, medium skin tone	family
👨🏽‍❤️‍👨🏾	couple with heart: man, man, medium skin tone, medium-dark skin tone	family
👨🏽‍❤️‍👨🏿	couple with heart: man, man, medium skin tone, dark skin tone	family
👨🏾‍❤️‍👨🏻	couple with heart: man, man, medium-dark skin tone, light skin tone	family
👨🏾‍❤️‍👨🏼	couple with heart: man, man, medium-dark skin tone, medium-light skin tone	family
👨🏾‍❤️‍👨🏽	couple with heart: man, man, medium-dark skin tone, medium skin tone	family
👨🏾‍❤️‍👨🏾	couple with heart: man, man, medium-dark skin tone	family
👨🏾‍❤️‍👨🏿	couple with heart: man, man, medium-dark skin tone, dark skin tone	family
👨🏿‍❤️‍👨🏻	couple with heart: man, man, dark skin tone, light skin tone	family
👨🏿‍❤️‍👨🏼	couple with heart: man, man, dark skin tone, medium-light skin tone	family
👨🏿‍❤️‍👨🏽	couple with heart: man, man, dark skin tone, medium skin tone	family
👨🏿‍❤️‍👨🏾	couple with heart: man, man, dark skin tone, medium-dark skin tone	family
👨🏿‍❤️‍👨🏿	couple with heart: man, man, dark skin tone	family
👩‍❤️‍👩	couple with heart: woman, woman	family
👩🏻‍❤️‍👩🏻	couple with heart: woman, woman, light skin tone	family
👩🏻‍❤️‍👩🏼	couple with heart: woman, woman, light skin tone, medium-light skin tone	family
👩🏻‍❤️‍👩🏽	couple with heart: woman, woman, light skin tone, medium skin tone	family
👩🏻‍❤️‍👩🏾	couple with heart: woman, woman, light skin tone, medium-dark skin tone	family
👩🏻‍❤️‍👩🏿	couple with heart: woman, woman, light skin tone, dark skin tone	family
👩🏼‍❤️‍👩🏻	couple with heart: woman, woman, medium-light skin tone, light skin tone	family
👩🏼‍❤️‍👩🏼	couple with heart: woman, woman, medium-light skin tone	family
👩🏼‍❤️‍👩🏽	couple with heart: woman, woman, medium-light skin tone, medium skin tone	family
👩🏼‍❤️‍👩🏾	couple with heart: woman, woman, medium-light skin tone, medium-dark skin tone	family
👩🏼‍❤️‍👩🏿	couple with heart: woman, woman, medium-light skin tone, dark skin tone	family
👩🏽‍❤️‍👩🏻	couple with heart: woman, woman, medium skin tone, light skin tone	family
👩🏽‍❤️‍👩🏼	couple with heart: woman, woman, medium skin tone, medium-light skin tone	family
👩🏽‍❤️‍👩🏽	couple with heart: woman, woman, medium skin tone	family
👩🏽‍❤️‍👩🏾	couple with heart: woman, woman, medium skin tone, medium-dark skin tone	family
👩🏽‍❤️‍👩🏿	couple with heart: woman, woman, medium skin tone, dark skin tone	family
👩🏾‍❤️‍👩🏻	couple with heart: woman, woman, medium-dark skin tone, light skin tone	family
👩🏾‍❤️‍👩🏼	couple with heart: woman, woman, medium-dark skin tone, medium-light skin tone	family
👩🏾‍❤️‍👩🏽	couple with heart: woman, woman, medium-dark skin tone, medium skin tone	family
👩🏾‍❤️‍👩🏾	couple with heart: woman, woman, medium-dark skin tone	family
👩🏾‍❤️‍👩🏿	couple with heart: woman, woman, medium-dark skin tone, dark skin tone	family
👩🏿‍❤️‍👩🏻	couple with heart: woman, woman, dark skin tone, light skin tone	family
👩🏿‍❤️‍👩🏼	couple with heart: woman, woman, dark skin tone, medium-light skin tone	family
👩🏿‍❤️‍👩🏽	couple with heart: woman, woman, dark skin tone, medium skin tone	family
👩🏿‍❤️‍👩🏾	couple with heart: woman, woman, dark skin tone, medium-dark skin tone	family
👩🏿‍❤️‍👩🏿	couple with heart: woman, woman, dark skin tone	family
👨‍👩‍👦	family: man, woman, boy	family
👨‍👩‍👧	family: man, woman, girl	family
👨‍👩‍👧‍👦	family: man, woman, girl, boy	family
👨‍👩‍👦‍👦	family: man, woman, boy, boy	family
👨‍👩‍👧‍👧	family: man, woman, girl, girl	family
👨‍👨‍👦	family: man, man, boy	family
👨‍👨‍👧	family: man, man, girl	family
👨‍👨‍👧‍👦	family: man, man, girl, boy	family
👨‍👨‍👦‍👦	family: man, man, boy, boy	family
👨‍👨‍👧‍👧	family: man, man, girl, girl	family
👩‍👩‍👦	family: woman, woman, boy	family
👩‍👩‍👧	family: woman, woman, girl	family
👩‍👩‍👧‍👦	family: woman, woman, girl, boy	family
👩‍👩‍👦‍👦	family: woman, woman, boy, boy	family
👩‍👩‍👧‍👧	family: woman, woman, girl, girl	family
👨‍👦	family: man, boy	family
👨‍👦‍👦	family: man, boy, boy	family
👨‍👧	family: man, girl	family
👨‍👧‍👦	family: man, girl, boy	family
👨‍👧‍👧	family: man, girl, girl	family
👩‍👦	family: woman, boy	family
👩‍👦‍👦	family: woman, boy, boy	family
👩‍👧	family: woman, girl	family
👩‍👧‍👦	family: woman, girl, boy	family
👩‍👧‍👧	family: woman, girl, girl	family
🗣️	speaking head	person-symbol
👤	bust in silhouette	person-symbol
👥	busts in silhouette	person-symbol
🫂	people hugging	person-symbol
👪	family	person-symbol
🧑‍🧑‍🧒	family: adult, adult, child	person-symbol
🧑‍🧑‍🧒‍🧒	family: adult, adult, child, child	person-symbol
🧑‍🧒	family: adult, child	person-symbol
🧑‍🧒‍🧒	family: adult, child, child	person-symbol
👣	footprints	person-symbol
🫆	fingerprint	person-symbol
@Animals & Nature	leaf.fill
🐵	monkey face	animal-mammal
🐒	monkey	animal-mammal
🦍	gorilla	animal-mammal
🦧	orangutan	animal-mammal
🐶	dog face	animal-mammal
🐕	dog	animal-mammal
🦮	guide dog	animal-mammal
🐕‍🦺	service dog	animal-mammal
🐩	poodle	animal-mammal
🐺	wolf	animal-mammal
🦊	fox	animal-mammal
🦝	raccoon	animal-mammal
🐱	cat face	animal-mammal
🐈	cat	animal-mammal
🐈‍⬛	black cat	animal-mammal
🦁	lion	animal-mammal
🐯	tiger face	animal-mammal
🐅	tiger	animal-mammal
🐆	leopard	animal-mammal
🐴	horse face	animal-mammal
🫎	moose	animal-mammal
🫏	donkey	animal-mammal
🐎	horse	animal-mammal
🦄	unicorn	animal-mammal
🦓	zebra	animal-mammal
🦌	deer	animal-mammal
🦬	bison	animal-mammal
🐮	cow face	animal-mammal
🐂	ox	animal-mammal
🐃	water buffalo	animal-mammal
🐄	cow	animal-mammal
🐷	pig face	animal-mammal
🐖	pig	animal-mammal
🐗	boar	animal-mammal
🐽	pig nose	animal-mammal
🐏	ram	animal-mammal
🐑	ewe	animal-mammal
🐐	goat	animal-mammal
🐪	camel	animal-mammal
🐫	two-hump camel	animal-mammal
🦙	llama	animal-mammal
🦒	giraffe	animal-mammal
🐘	elephant	animal-mammal
🦣	mammoth	animal-mammal
🦏	rhinoceros	animal-mammal
🦛	hippopotamus	animal-mammal
🐭	mouse face	animal-mammal
🐁	mouse	animal-mammal
🐀	rat	animal-mammal
🐹	hamster	animal-mammal
🐰	rabbit face	animal-mammal
🐇	rabbit	animal-mammal
🐿️	chipmunk	animal-mammal
🦫	beaver	animal-mammal
🦔	hedgehog	animal-mammal
🦇	bat	animal-mammal
🐻	bear	animal-mammal
🐻‍❄️	polar bear	animal-mammal
🐨	koala	animal-mammal
🐼	panda	animal-mammal
🦥	sloth	animal-mammal
🦦	otter	animal-mammal
🦨	skunk	animal-mammal
🦘	kangaroo	animal-mammal
🦡	badger	animal-mammal
🐾	paw prints	animal-mammal
🦃	turkey	animal-bird
🐔	chicken	animal-bird
🐓	rooster	animal-bird
🐣	hatching chick	animal-bird
🐤	baby chick	animal-bird
🐥	front-facing baby chick	animal-bird
🐦	bird	animal-bird
🐧	penguin	animal-bird
🕊️	dove	animal-bird
🦅	eagle	animal-bird
🦆	duck	animal-bird
🦢	swan	animal-bird
🦉	owl	animal-bird
🦤	dodo	animal-bird
🪶	feather	animal-bird
🦩	flamingo	animal-bird
🦚	peacock	animal-bird
🦜	parrot	animal-bird
🪽	wing	animal-bird
🐦‍⬛	black bird	animal-bird
🪿	goose	animal-bird
🐦‍🔥	phoenix	animal-bird
🐸	frog	animal-amphibian
🐊	crocodile	animal-reptile
🐢	turtle	animal-reptile
🦎	lizard	animal-reptile
🐍	snake	animal-reptile
🐲	dragon face	animal-reptile
🐉	dragon	animal-reptile
🦕	sauropod	animal-reptile
🦖	T-Rex	animal-reptile
🐳	spouting whale	animal-marine
🐋	whale	animal-marine
🐬	dolphin	animal-marine
🫍	orca	animal-marine
🦭	seal	animal-marine
🐟	fish	animal-marine
🐠	tropical fish	animal-marine
🐡	blowfish	animal-marine
🦈	shark	animal-marine
🐙	octopus	animal-marine
🐚	spiral shell	animal-marine
🪸	coral	animal-marine
🪼	jellyfish	animal-marine
🦀	crab	animal-marine
🦞	lobster	animal-marine
🦐	shrimp	animal-marine
🦑	squid	animal-marine
🦪	oyster	animal-marine
🐌	snail	animal-bug
🦋	butterfly	animal-bug
🐛	bug	animal-bug
🐜	ant	animal-bug
🐝	honeybee	animal-bug
🪲	beetle	animal-bug
🐞	lady beetle	animal-bug
🦗	cricket	animal-bug
🪳	cockroach	animal-bug
🕷️	spider	animal-bug
🕸️	spider web	animal-bug
🦂	scorpion	animal-bug
🦟	mosquito	animal-bug
🪰	fly	animal-bug
🪱	worm	animal-bug
🦠	microbe	animal-bug
💐	bouquet	plant-flower
🌸	cherry blossom	plant-flower
💮	white flower	plant-flower
🪷	lotus	plant-flower
🏵️	rosette	plant-flower
🌹	rose	plant-flower
🥀	wilted flower	plant-flower
🌺	hibiscus	plant-flower
🌻	sunflower	plant-flower
🌼	blossom	plant-flower
🌷	tulip	plant-flower
🪻	hyacinth	plant-flower
🌱	seedling	plant-other
🪴	potted plant	plant-other
🌲	evergreen tree	plant-other
🌳	deciduous tree	plant-other
🌴	palm tree	plant-other
🌵	cactus	plant-other
🌾	sheaf of rice	plant-other
🌿	herb	plant-other
☘️	shamrock	plant-other
🍀	four leaf clover	plant-other
🍁	maple leaf	plant-other
🍂	fallen leaf	plant-other
🍃	leaf fluttering in wind	plant-other
🪹	empty nest	plant-other
🪺	nest with eggs	plant-other
🍄	mushroom	plant-other
🪾	leafless tree	plant-other
@Food & Drink	fork.knife
🍇	grapes	food-fruit
🍈	melon	food-fruit
🍉	watermelon	food-fruit
🍊	tangerine	food-fruit
🍋	lemon	food-fruit
🍋‍🟩	lime	food-fruit
🍌	banana	food-fruit
🍍	pineapple	food-fruit
🥭	mango	food-fruit
🍎	red apple	food-fruit
🍏	green apple	food-fruit
🍐	pear	food-fruit
🍑	peach	food-fruit
🍒	cherries	food-fruit
🍓	strawberry	food-fruit
🫐	blueberries	food-fruit
🥝	kiwi fruit	food-fruit
🍅	tomato	food-fruit
🫒	olive	food-fruit
🥥	coconut	food-fruit
🥑	avocado	food-vegetable
🍆	eggplant	food-vegetable
🥔	potato	food-vegetable
🥕	carrot	food-vegetable
🌽	ear of corn	food-vegetable
🌶️	hot pepper	food-vegetable
🫑	bell pepper	food-vegetable
🥒	cucumber	food-vegetable
🥬	leafy green	food-vegetable
🥦	broccoli	food-vegetable
🧄	garlic	food-vegetable
🧅	onion	food-vegetable
🥜	peanuts	food-vegetable
🫘	beans	food-vegetable
🌰	chestnut	food-vegetable
🫚	ginger root	food-vegetable
🫛	pea pod	food-vegetable
🍄‍🟫	brown mushroom	food-vegetable
🫜	root vegetable	food-vegetable
🍞	bread	food-prepared
🥐	croissant	food-prepared
🥖	baguette bread	food-prepared
🫓	flatbread	food-prepared
🥨	pretzel	food-prepared
🥯	bagel	food-prepared
🥞	pancakes	food-prepared
🧇	waffle	food-prepared
🧀	cheese wedge	food-prepared
🍖	meat on bone	food-prepared
🍗	poultry leg	food-prepared
🥩	cut of meat	food-prepared
🥓	bacon	food-prepared
🍔	hamburger	food-prepared
🍟	french fries	food-prepared
🍕	pizza	food-prepared
🌭	hot dog	food-prepared
🥪	sandwich	food-prepared
🌮	taco	food-prepared
🌯	burrito	food-prepared
🫔	tamale	food-prepared
🥙	stuffed flatbread	food-prepared
🧆	falafel	food-prepared
🥚	egg	food-prepared
🍳	cooking	food-prepared
🥘	shallow pan of food	food-prepared
🍲	pot of food	food-prepared
🫕	fondue	food-prepared
🥣	bowl with spoon	food-prepared
🥗	green salad	food-prepared
🍿	popcorn	food-prepared
🧈	butter	food-prepared
🧂	salt	food-prepared
🥫	canned food	food-prepared
🍱	bento box	food-asian
🍘	rice cracker	food-asian
🍙	rice ball	food-asian
🍚	cooked rice	food-asian
🍛	curry rice	food-asian
🍜	steaming bowl	food-asian
🍝	spaghetti	food-asian
🍠	roasted sweet potato	food-asian
🍢	oden	food-asian
🍣	sushi	food-asian
🍤	fried shrimp	food-asian
🍥	fish cake with swirl	food-asian
🥮	moon cake	food-asian
🍡	dango	food-asian
🥟	dumpling	food-asian
🥠	fortune cookie	food-asian
🥡	takeout box	food-asian
🍦	soft ice cream	food-sweet
🍧	shaved ice	food-sweet
🍨	ice cream	food-sweet
🍩	doughnut	food-sweet
🍪	cookie	food-sweet
🎂	birthday cake	food-sweet
🍰	shortcake	food-sweet
🧁	cupcake	food-sweet
🥧	pie	food-sweet
🍫	chocolate bar	food-sweet
🍬	candy	food-sweet
🍭	lollipop	food-sweet
🍮	custard	food-sweet
🍯	honey pot	food-sweet
🍼	baby bottle	drink
🥛	glass of milk	drink
☕	hot beverage	drink
🫖	teapot	drink
🍵	teacup without handle	drink
🍶	sake	drink
🍾	bottle with popping cork	drink
🍷	wine glass	drink
🍸	cocktail glass	drink
🍹	tropical drink	drink
🍺	beer mug	drink
🍻	clinking beer mugs	drink
🥂	clinking glasses	drink
🥃	tumbler glass	drink
🫗	pouring liquid	drink
🥤	cup with straw	drink
🧋	bubble tea	drink
🧃	beverage box	drink
🧉	mate	drink
🧊	ice	drink
🥢	chopsticks	dishware
🍽️	fork and knife with plate	dishware
🍴	fork and knife	dishware
🥄	spoon	dishware
🔪	kitchen knife	dishware
🫙	jar	dishware
🏺	amphora	dishware
@Travel & Places	car.fill
🌍	globe showing Europe-Africa	place-map
🌎	globe showing Americas	place-map
🌏	globe showing Asia-Australia	place-map
🌐	globe with meridians	place-map
🗺️	world map	place-map
🗾	map of Japan	place-map
🧭	compass	place-map
🏔️	snow-capped mountain	place-geographic
⛰️	mountain	place-geographic
🛘	landslide	place-geographic
🌋	volcano	place-geographic
🗻	mount fuji	place-geographic
🏕️	camping	place-geographic
🏖️	beach with umbrella	place-geographic
🏜️	desert	place-geographic
🏝️	desert island	place-geographic
🏞️	national park	place-geographic
🏟️	stadium	place-building
🏛️	classical building	place-building
🏗️	building construction	place-building
🧱	brick	place-building
🪨	rock	place-building
🪵	wood	place-building
🛖	hut	place-building
🏘️	houses	place-building
🏚️	derelict house	place-building
🏠	house	place-building
🏡	house with garden	place-building
🏢	office building	place-building
🏣	Japanese post office	place-building
🏤	post office	place-building
🏥	hospital	place-building
🏦	bank	place-building
🏨	hotel	place-building
🏩	love hotel	place-building
🏪	convenience store	place-building
🏫	school	place-building
🏬	department store	place-building
🏭	factory	place-building
🏯	Japanese castle	place-building
🏰	castle	place-building
💒	wedding	place-building
🗼	Tokyo tower	place-building
🗽	Statue of Liberty	place-building
⛪	church	place-religious
🕌	mosque	place-religious
🛕	hindu temple	place-religious
🕍	synagogue	place-religious
⛩️	shinto shrine	place-religious
🕋	kaaba	place-religious
⛲	fountain	place-other
⛺	tent	place-other
🌁	foggy	place-other
🌃	night with stars	place-other
🏙️	cityscape	place-other
🌄	sunrise over mountains	place-other
🌅	sunrise	place-other
🌆	cityscape at dusk	place-other
🌇	sunset	place-other
🌉	bridge at night	place-other
♨️	hot springs	place-other
🎠	carousel horse	place-other
🛝	playground slide	place-other
🎡	ferris wheel	place-other
🎢	roller coaster	place-other
💈	barber pole	place-other
🎪	circus tent	place-other
🚂	locomotive	transport-ground
🚃	railway car	transport-ground
🚄	high-speed train	transport-ground
🚅	bullet train	transport-ground
🚆	train	transport-ground
🚇	metro	transport-ground
🚈	light rail	transport-ground
🚉	station	transport-ground
🚊	tram	transport-ground
🚝	monorail	transport-ground
🚞	mountain railway	transport-ground
🚋	tram car	transport-ground
🚌	bus	transport-ground
🚍	oncoming bus	transport-ground
🚎	trolleybus	transport-ground
🚐	minibus	transport-ground
🚑	ambulance	transport-ground
🚒	fire engine	transport-ground
🚓	police car	transport-ground
🚔	oncoming police car	transport-ground
🚕	taxi	transport-ground
🚖	oncoming taxi	transport-ground
🚗	automobile	transport-ground
🚘	oncoming automobile	transport-ground
🚙	sport utility vehicle	transport-ground
🛻	pickup truck	transport-ground
🚚	delivery truck	transport-ground
🚛	articulated lorry	transport-ground
🚜	tractor	transport-ground
🏎️	racing car	transport-ground
🏍️	motorcycle	transport-ground
🛵	motor scooter	transport-ground
🦽	manual wheelchair	transport-ground
🦼	motorized wheelchair	transport-ground
🛺	auto rickshaw	transport-ground
🚲	bicycle	transport-ground
🛴	kick scooter	transport-ground
🛹	skateboard	transport-ground
🛼	roller skate	transport-ground
🚏	bus stop	transport-ground
🛣️	motorway	transport-ground
🛤️	railway track	transport-ground
🛢️	oil drum	transport-ground
⛽	fuel pump	transport-ground
🛞	wheel	transport-ground
🚨	police car light	transport-ground
🚥	horizontal traffic light	transport-ground
🚦	vertical traffic light	transport-ground
🛑	stop sign	transport-ground
🚧	construction	transport-ground
⚓	anchor	transport-water
🛟	ring buoy	transport-water
⛵	sailboat	transport-water
🛶	canoe	transport-water
🚤	speedboat	transport-water
🛳️	passenger ship	transport-water
⛴️	ferry	transport-water
🛥️	motor boat	transport-water
🚢	ship	transport-water
✈️	airplane	transport-air
🛩️	small airplane	transport-air
🛫	airplane departure	transport-air
🛬	airplane arrival	transport-air
🪂	parachute	transport-air
💺	seat	transport-air
🚁	helicopter	transport-air
🚟	suspension railway	transport-air
🚠	mountain cableway	transport-air
🚡	aerial tramway	transport-air
🛰️	satellite	transport-air
🚀	rocket	transport-air
🛸	flying saucer	transport-air
🛎️	bellhop bell	hotel
🧳	luggage	hotel
⌛	hourglass done	time
⏳	hourglass not done	time
⌚	watch	time
⏰	alarm clock	time
⏱️	stopwatch	time
⏲️	timer clock	time
🕰️	mantelpiece clock	time
🕛	twelve o’clock	time
🕧	twelve-thirty	time
🕐	one o’clock	time
🕜	one-thirty	time
🕑	two o’clock	time
🕝	two-thirty	time
🕒	three o’clock	time
🕞	three-thirty	time
🕓	four o’clock	time
🕟	four-thirty	time
🕔	five o’clock	time
🕠	five-thirty	time
🕕	six o’clock	time
🕡	six-thirty	time
🕖	seven o’clock	time
🕢	seven-thirty	time
🕗	eight o’clock	time
🕣	eight-thirty	time
🕘	nine o’clock	time
🕤	nine-thirty	time
🕙	ten o’clock	time
🕥	ten-thirty	time
🕚	eleven o’clock	time
🕦	eleven-thirty	time
🌑	new moon	sky & weather
🌒	waxing crescent moon	sky & weather
🌓	first quarter moon	sky & weather
🌔	waxing gibbous moon	sky & weather
🌕	full moon	sky & weather
🌖	waning gibbous moon	sky & weather
🌗	last quarter moon	sky & weather
🌘	waning crescent moon	sky & weather
🌙	crescent moon	sky & weather
🌚	new moon face	sky & weather
🌛	first quarter moon face	sky & weather
🌜	last quarter moon face	sky & weather
🌡️	thermometer	sky & weather
☀️	sun	sky & weather
🌝	full moon face	sky & weather
🌞	sun with face	sky & weather
🪐	ringed planet	sky & weather
⭐	star	sky & weather
🌟	glowing star	sky & weather
🌠	shooting star	sky & weather
🌌	milky way	sky & weather
☁️	cloud	sky & weather
⛅	sun behind cloud	sky & weather
⛈️	cloud with lightning and rain	sky & weather
🌤️	sun behind small cloud	sky & weather
🌥️	sun behind large cloud	sky & weather
🌦️	sun behind rain cloud	sky & weather
🌧️	cloud with rain	sky & weather
🌨️	cloud with snow	sky & weather
🌩️	cloud with lightning	sky & weather
🌪️	tornado	sky & weather
🌫️	fog	sky & weather
🌬️	wind face	sky & weather
🌀	cyclone	sky & weather
🌈	rainbow	sky & weather
🌂	closed umbrella	sky & weather
☂️	umbrella	sky & weather
☔	umbrella with rain drops	sky & weather
⛱️	umbrella on ground	sky & weather
⚡	high voltage	sky & weather
❄️	snowflake	sky & weather
☃️	snowman	sky & weather
⛄	snowman without snow	sky & weather
☄️	comet	sky & weather
🔥	fire	sky & weather
💧	droplet	sky & weather
🌊	water wave	sky & weather
@Activities	basketball.fill
🎃	jack-o-lantern	event
🎄	Christmas tree	event
🎆	fireworks	event
🎇	sparkler	event
🧨	firecracker	event
✨	sparkles	event
🎈	balloon	event
🎉	party popper	event
🎊	confetti ball	event
🎋	tanabata tree	event
🎍	pine decoration	event
🎎	Japanese dolls	event
🎏	carp streamer	event
🎐	wind chime	event
🎑	moon viewing ceremony	event
🧧	red envelope	event
🎀	ribbon	event
🎁	wrapped gift	event
🎗️	reminder ribbon	event
🎟️	admission tickets	event
🎫	ticket	event
🎖️	military medal	award-medal
🏆	trophy	award-medal
🏅	sports medal	award-medal
🥇	1st place medal	award-medal
🥈	2nd place medal	award-medal
🥉	3rd place medal	award-medal
⚽	soccer ball	sport
⚾	baseball	sport
🥎	softball	sport
🏀	basketball	sport
🏐	volleyball	sport
🏈	american football	sport
🏉	rugby football	sport
🎾	tennis	sport
🥏	flying disc	sport
🎳	bowling	sport
🏏	cricket game	sport
🏑	field hockey	sport
🏒	ice hockey	sport
🥍	lacrosse	sport
🏓	ping pong	sport
🏸	badminton	sport
🥊	boxing glove	sport
🥋	martial arts uniform	sport
🥅	goal net	sport
⛳	flag in hole	sport
⛸️	ice skate	sport
🎣	fishing pole	sport
🤿	diving mask	sport
🎽	running shirt	sport
🎿	skis	sport
🛷	sled	sport
🥌	curling stone	sport
🎯	bullseye	game
🪀	yo-yo	game
🪁	kite	game
🔫	water pistol	game
🎱	pool 8 ball	game
🔮	crystal ball	game
🪄	magic wand	game
🎮	video game	game
🕹️	joystick	game
🎰	slot machine	game
🎲	game die	game
🧩	puzzle piece	game
🧸	teddy bear	game
🪅	piñata	game
🪩	mirror ball	game
🪆	nesting dolls	game
♠️	spade suit	game
♥️	heart suit	game
♦️	diamond suit	game
♣️	club suit	game
♟️	chess pawn	game
🃏	joker	game
🀄	mahjong red dragon	game
🎴	flower playing cards	game
🎭	performing arts	arts & crafts
🖼️	framed picture	arts & crafts
🎨	artist palette	arts & crafts
🧵	thread	arts & crafts
🪡	sewing needle	arts & crafts
🧶	yarn	arts & crafts
🪢	knot	arts & crafts
@Objects	crown.fill
👓	glasses	clothing
🕶️	sunglasses	clothing
🥽	goggles	clothing
🥼	lab coat	clothing
🦺	safety vest	clothing
👔	necktie	clothing
👕	t-shirt	clothing
👖	jeans	clothing
🧣	scarf	clothing
🧤	gloves	clothing
🧥	coat	clothing
🧦	socks	clothing
👗	dress	clothing
👘	kimono	clothing
🥻	sari	clothing
🩱	one-piece swimsuit	clothing
🩲	briefs	clothing
🩳	shorts	clothing
👙	bikini	clothing
👚	woman’s clothes	clothing
🪭	folding hand fan	clothing
👛	purse	clothing
👜	handbag	clothing
👝	clutch bag	clothing
🛍️	shopping bags	clothing
🎒	backpack	clothing
🩴	thong sandal	clothing
👞	man’s shoe	clothing
👟	running shoe	clothing
🥾	hiking boot	clothing
🥿	flat shoe	clothing
👠	high-heeled shoe	clothing
👡	woman’s sandal	clothing
🩰	ballet shoes	clothing
👢	woman’s boot	clothing
🪮	hair pick	clothing
👑	crown	clothing
👒	woman’s hat	clothing
🎩	top hat	clothing
🎓	graduation cap	clothing
🧢	billed cap	clothing
🪖	military helmet	clothing
⛑️	rescue worker’s helmet	clothing
📿	prayer beads	clothing
💄	lipstick	clothing
💍	ring	clothing
💎	gem stone	clothing
🔇	muted speaker	sound
🔈	speaker low volume	sound
🔉	speaker medium volume	sound
🔊	speaker high volume	sound
📢	loudspeaker	sound
📣	megaphone	sound
📯	postal horn	sound
🔔	bell	sound
🔕	bell with slash	sound
🎼	musical score	music
🎵	musical note	music
🎶	musical notes	music
🎙️	studio microphone	music
🎚️	level slider	music
🎛️	control knobs	music
🎤	microphone	music
🎧	headphone	music
📻	radio	music
🎷	saxophone	musical-instrument
🎺	trumpet	musical-instrument
🪊	trombone	musical-instrument
🪗	accordion	musical-instrument
🎸	guitar	musical-instrument
🎹	musical keyboard	musical-instrument
🎻	violin	musical-instrument
🪕	banjo	musical-instrument
🥁	drum	musical-instrument
🪘	long drum	musical-instrument
🪇	maracas	musical-instrument
🪈	flute	musical-instrument
🪉	harp	musical-instrument
📱	mobile phone	phone
📲	mobile phone with arrow	phone
☎️	telephone	phone
📞	telephone receiver	phone
📟	pager	phone
📠	fax machine	phone
🔋	battery	computer
🪫	low battery	computer
🔌	electric plug	computer
💻	laptop	computer
🖥️	desktop computer	computer
🖨️	printer	computer
⌨️	keyboard	computer
🖱️	computer mouse	computer
🖲️	trackball	computer
💽	computer disk	computer
💾	floppy disk	computer
💿	optical disk	computer
📀	dvd	computer
🧮	abacus	computer
🎥	movie camera	light & video
🎞️	film frames	light & video
📽️	film projector	light & video
🎬	clapper board	light & video
📺	television	light & video
📷	camera	light & video
📸	camera with flash	light & video
📹	video camera	light & video
📼	videocassette	light & video
🔍	magnifying glass tilted left	light & video
🔎	magnifying glass tilted right	light & video
🕯️	candle	light & video
💡	light bulb	light & video
🔦	flashlight	light & video
🏮	red paper lantern	light & video
🪔	diya lamp	light & video
📔	notebook with decorative cover	book-paper
📕	closed book	book-paper
📖	open book	book-paper
📗	green book	book-paper
📘	blue book	book-paper
📙	orange book	book-paper
📚	books	book-paper
📓	notebook	book-paper
📒	ledger	book-paper
📃	page with curl	book-paper
📜	scroll	book-paper
📄	page facing up	book-paper
📰	newspaper	book-paper
🗞️	rolled-up newspaper	book-paper
📑	bookmark tabs	book-paper
🔖	bookmark	book-paper
🏷️	label	book-paper
🪙	coin	money
💰	money bag	money
🪎	treasure chest	money
💴	yen banknote	money
💵	dollar banknote	money
💶	euro banknote	money
💷	pound banknote	money
💸	money with wings	money
💳	credit card	money
🧾	receipt	money
💹	chart increasing with yen	money
✉️	envelope	mail
📧	e-mail	mail
📨	incoming envelope	mail
📩	envelope with arrow	mail
📤	outbox tray	mail
📥	inbox tray	mail
📦	package	mail
📫	closed mailbox with raised flag	mail
📪	closed mailbox with lowered flag	mail
📬	open mailbox with raised flag	mail
📭	open mailbox with lowered flag	mail
📮	postbox	mail
🗳️	ballot box with ballot	mail
✏️	pencil	writing
✒️	black nib	writing
🖋️	fountain pen	writing
🖊️	pen	writing
🖌️	paintbrush	writing
🖍️	crayon	writing
📝	memo	writing
💼	briefcase	office
📁	file folder	office
📂	open file folder	office
🗂️	card index dividers	office
📅	calendar	office
📆	tear-off calendar	office
🗒️	spiral notepad	office
🗓️	spiral calendar	office
📇	card index	office
📈	chart increasing	office
📉	chart decreasing	office
📊	bar chart	office
📋	clipboard	office
📌	pushpin	office
📍	round pushpin	office
📎	paperclip	office
🖇️	linked paperclips	office
📏	straight ruler	office
📐	triangular ruler	office
✂️	scissors	office
🗃️	card file box	office
🗄️	file cabinet	office
🗑️	wastebasket	office
🔒	locked	lock
🔓	unlocked	lock
🔏	locked with pen	lock
🔐	locked with key	lock
🔑	key	lock
🗝️	old key	lock
🔨	hammer	tool
🪓	axe	tool
⛏️	pick	tool
⚒️	hammer and pick	tool
🛠️	hammer and wrench	tool
🗡️	dagger	tool
⚔️	crossed swords	tool
💣	bomb	tool
🪃	boomerang	tool
🏹	bow and arrow	tool
🛡️	shield	tool
🪚	carpentry saw	tool
🔧	wrench	tool
🪛	screwdriver	tool
🔩	nut and bolt	tool
⚙️	gear	tool
🗜️	clamp	tool
⚖️	balance scale	tool
🦯	white cane	tool
🔗	link	tool
⛓️‍💥	broken chain	tool
⛓️	chains	tool
🪝	hook	tool
🧰	toolbox	tool
🧲	magnet	tool
🪜	ladder	tool
🪏	shovel	tool
⚗️	alembic	science
🧪	test tube	science
🧫	petri dish	science
🧬	dna	science
🔬	microscope	science
🔭	telescope	science
📡	satellite antenna	science
💉	syringe	medical
🩸	drop of blood	medical
💊	pill	medical
🩹	adhesive bandage	medical
🩼	crutch	medical
🩺	stethoscope	medical
🩻	x-ray	medical
🚪	door	household
🛗	elevator	household
🪞	mirror	household
🪟	window	household
🛏️	bed	household
🛋️	couch and lamp	household
🪑	chair	household
🚽	toilet	household
🪠	plunger	household
🚿	shower	household
🛁	bathtub	household
🪤	mouse trap	household
🪒	razor	household
🧴	lotion bottle	household
🧷	safety pin	household
🧹	broom	household
🧺	basket	household
🧻	roll of paper	household
🪣	bucket	household
🧼	soap	household
🫧	bubbles	household
🪥	toothbrush	household
🧽	sponge	household
🧯	fire extinguisher	household
🛒	shopping cart	household
🚬	cigarette	other-object
⚰️	coffin	other-object
🪦	headstone	other-object
⚱️	funeral urn	other-object
🧿	nazar amulet	other-object
🪬	hamsa	other-object
🗿	moai	other-object
🪧	placard	other-object
🪪	identification card	other-object
@Symbols	diamond.fill
🏧	ATM sign	transport-sign
🚮	litter in bin sign	transport-sign
🚰	potable water	transport-sign
♿	wheelchair symbol	transport-sign
🚹	men’s room	transport-sign
🚺	women’s room	transport-sign
🚻	restroom	transport-sign
🚼	baby symbol	transport-sign
🚾	water closet	transport-sign
🛂	passport control	transport-sign
🛃	customs	transport-sign
🛄	baggage claim	transport-sign
🛅	left luggage	transport-sign
⚠️	warning	warning
🚸	children crossing	warning
⛔	no entry	warning
🚫	prohibited	warning
🚳	no bicycles	warning
🚭	no smoking	warning
🚯	no littering	warning
🚱	non-potable water	warning
🚷	no pedestrians	warning
📵	no mobile phones	warning
🔞	no one under eighteen	warning
☢️	radioactive	warning
☣️	biohazard	warning
⬆️	up arrow	arrow
↗️	up-right arrow	arrow
➡️	right arrow	arrow
↘️	down-right arrow	arrow
⬇️	down arrow	arrow
↙️	down-left arrow	arrow
⬅️	left arrow	arrow
↖️	up-left arrow	arrow
↕️	up-down arrow	arrow
↔️	left-right arrow	arrow
↩️	right arrow curving left	arrow
↪️	left arrow curving right	arrow
⤴️	right arrow curving up	arrow
⤵️	right arrow curving down	arrow
🔃	clockwise vertical arrows	arrow
🔄	counterclockwise arrows button	arrow
🔙	BACK arrow	arrow
🔚	END arrow	arrow
🔛	ON! arrow	arrow
🔜	SOON arrow	arrow
🔝	TOP arrow	arrow
🛐	place of worship	religion
⚛️	atom symbol	religion
🕉️	om	religion
✡️	star of David	religion
☸️	wheel of dharma	religion
☯️	yin yang	religion
✝️	latin cross	religion
☦️	orthodox cross	religion
☪️	star and crescent	religion
☮️	peace symbol	religion
🕎	menorah	religion
🔯	dotted six-pointed star	religion
🪯	khanda	religion
♈	Aries	zodiac
♉	Taurus	zodiac
♊	Gemini	zodiac
♋	Cancer	zodiac
♌	Leo	zodiac
♍	Virgo	zodiac
♎	Libra	zodiac
♏	Scorpio	zodiac
♐	Sagittarius	zodiac
♑	Capricorn	zodiac
♒	Aquarius	zodiac
♓	Pisces	zodiac
⛎	Ophiuchus	zodiac
🔀	shuffle tracks button	av-symbol
🔁	repeat button	av-symbol
🔂	repeat single button	av-symbol
▶️	play button	av-symbol
⏩	fast-forward button	av-symbol
⏭️	next track button	av-symbol
⏯️	play or pause button	av-symbol
◀️	reverse button	av-symbol
⏪	fast reverse button	av-symbol
⏮️	last track button	av-symbol
🔼	upwards button	av-symbol
⏫	fast up button	av-symbol
🔽	downwards button	av-symbol
⏬	fast down button	av-symbol
⏸️	pause button	av-symbol
⏹️	stop button	av-symbol
⏺️	record button	av-symbol
⏏️	eject button	av-symbol
🎦	cinema	av-symbol
🔅	dim button	av-symbol
🔆	bright button	av-symbol
📶	antenna bars	av-symbol
🛜	wireless	av-symbol
📳	vibration mode	av-symbol
📴	mobile phone off	av-symbol
♀️	female sign	gender
♂️	male sign	gender
⚧️	transgender symbol	gender
✖️	multiply	math
➕	plus	math
➖	minus	math
➗	divide	math
🟰	heavy equals sign	math
♾️	infinity	math
‼️	double exclamation mark	punctuation
⁉️	exclamation question mark	punctuation
❓	red question mark	punctuation
❔	white question mark	punctuation
❕	white exclamation mark	punctuation
❗	red exclamation mark	punctuation
〰️	wavy dash	punctuation
💱	currency exchange	currency
💲	heavy dollar sign	currency
⚕️	medical symbol	other-symbol
♻️	recycling symbol	other-symbol
⚜️	fleur-de-lis	other-symbol
🔱	trident emblem	other-symbol
📛	name badge	other-symbol
🔰	Japanese symbol for beginner	other-symbol
⭕	hollow red circle	other-symbol
✅	check mark button	other-symbol
☑️	check box with check	other-symbol
✔️	check mark	other-symbol
❌	cross mark	other-symbol
❎	cross mark button	other-symbol
➰	curly loop	other-symbol
➿	double curly loop	other-symbol
〽️	part alternation mark	other-symbol
✳️	eight-spoked asterisk	other-symbol
✴️	eight-pointed star	other-symbol
❇️	sparkle	other-symbol
©️	copyright	other-symbol
®️	registered	other-symbol
™️	trade mark	other-symbol
🫟	splatter	other-symbol
#️⃣	keycap: #	keycap
*️⃣	keycap: *	keycap
0️⃣	keycap: 0	keycap
1️⃣	keycap: 1	keycap
2️⃣	keycap: 2	keycap
3️⃣	keycap: 3	keycap
4️⃣	keycap: 4	keycap
5️⃣	keycap: 5	keycap
6️⃣	keycap: 6	keycap
7️⃣	keycap: 7	keycap
8️⃣	keycap: 8	keycap
9️⃣	keycap: 9	keycap
🔟	keycap: 10	keycap
🔠	input latin uppercase	alphanum
🔡	input latin lowercase	alphanum
🔢	input numbers	alphanum
🔣	input symbols	alphanum
🔤	input latin letters	alphanum
🅰️	A button (blood type)	alphanum
🆎	AB button (blood type)	alphanum
🅱️	B button (blood type)	alphanum
🆑	CL button	alphanum
🆒	COOL button	alphanum
🆓	FREE button	alphanum
ℹ️	information	alphanum
🆔	ID button	alphanum
Ⓜ️	circled M	alphanum
🆕	NEW button	alphanum
🆖	NG button	alphanum
🅾️	O button (blood type)	alphanum
🆗	OK button	alphanum
🅿️	P button	alphanum
🆘	SOS button	alphanum
🆙	UP! button	alphanum
🆚	VS button	alphanum
🈁	Japanese “here” button	alphanum
🈂️	Japanese “service charge” button	alphanum
🈷️	Japanese “monthly amount” button	alphanum
🈶	Japanese “not free of charge” button	alphanum
🈯	Japanese “reserved” button	alphanum
🉐	Japanese “bargain” button	alphanum
🈹	Japanese “discount” button	alphanum
🈚	Japanese “free of charge” button	alphanum
🈲	Japanese “prohibited” button	alphanum
🉑	Japanese “acceptable” button	alphanum
🈸	Japanese “application” button	alphanum
🈴	Japanese “passing grade” button	alphanum
🈳	Japanese “vacancy” button	alphanum
㊗️	Japanese “congratulations” button	alphanum
㊙️	Japanese “secret” button	alphanum
🈺	Japanese “open for business” button	alphanum
🈵	Japanese “no vacancy” button	alphanum
🔴	red circle	geometric
🟠	orange circle	geometric
🟡	yellow circle	geometric
🟢	green circle	geometric
🔵	blue circle	geometric
🟣	purple circle	geometric
🟤	brown circle	geometric
⚫	black circle	geometric
⚪	white circle	geometric
🟥	red square	geometric
🟧	orange square	geometric
🟨	yellow square	geometric
🟩	green square	geometric
🟦	blue square	geometric
🟪	purple square	geometric
🟫	brown square	geometric
⬛	black large square	geometric
⬜	white large square	geometric
◼️	black medium square	geometric
◻️	white medium square	geometric
◾	black medium-small square	geometric
◽	white medium-small square	geometric
▪️	black small square	geometric
▫️	white small square	geometric
🔶	large orange diamond	geometric
🔷	large blue diamond	geometric
🔸	small orange diamond	geometric
🔹	small blue diamond	geometric
🔺	red triangle pointed up	geometric
🔻	red triangle pointed down	geometric
💠	diamond with a dot	geometric
🔘	radio button	geometric
🔳	white square button	geometric
🔲	black square button	geometric
@Flags	flag.fill
🏁	chequered flag	flag
🚩	triangular flag	flag
🎌	crossed flags	flag
🏴	black flag	flag
🏳️	white flag	flag
🏳️‍🌈	rainbow flag	flag
🏳️‍⚧️	transgender flag	flag
🏴‍☠️	pirate flag	flag
🇦🇨	flag: Ascension Island	country-flag
🇦🇩	flag: Andorra	country-flag
🇦🇪	flag: United Arab Emirates	country-flag
🇦🇫	flag: Afghanistan	country-flag
🇦🇬	flag: Antigua & Barbuda	country-flag
🇦🇮	flag: Anguilla	country-flag
🇦🇱	flag: Albania	country-flag
🇦🇲	flag: Armenia	country-flag
🇦🇴	flag: Angola	country-flag
🇦🇶	flag: Antarctica	country-flag
🇦🇷	flag: Argentina	country-flag
🇦🇸	flag: American Samoa	country-flag
🇦🇹	flag: Austria	country-flag
🇦🇺	flag: Australia	country-flag
🇦🇼	flag: Aruba	country-flag
🇦🇽	flag: Åland Islands	country-flag
🇦🇿	flag: Azerbaijan	country-flag
🇧🇦	flag: Bosnia & Herzegovina	country-flag
🇧🇧	flag: Barbados	country-flag
🇧🇩	flag: Bangladesh	country-flag
🇧🇪	flag: Belgium	country-flag
🇧🇫	flag: Burkina Faso	country-flag
🇧🇬	flag: Bulgaria	country-flag
🇧🇭	flag: Bahrain	country-flag
🇧🇮	flag: Burundi	country-flag
🇧🇯	flag: Benin	country-flag
🇧🇱	flag: St. Barthélemy	country-flag
🇧🇲	flag: Bermuda	country-flag
🇧🇳	flag: Brunei	country-flag
🇧🇴	flag: Bolivia	country-flag
🇧🇶	flag: Caribbean Netherlands	country-flag
🇧🇷	flag: Brazil	country-flag
🇧🇸	flag: Bahamas	country-flag
🇧🇹	flag: Bhutan	country-flag
🇧🇻	flag: Bouvet Island	country-flag
🇧🇼	flag: Botswana	country-flag
🇧🇾	flag: Belarus	country-flag
🇧🇿	flag: Belize	country-flag
🇨🇦	flag: Canada	country-flag
🇨🇨	flag: Cocos (Keeling) Islands	country-flag
🇨🇩	flag: Congo - Kinshasa	country-flag
🇨🇫	flag: Central African Republic	country-flag
🇨🇬	flag: Congo - Brazzaville	country-flag
🇨🇭	flag: Switzerland	country-flag
🇨🇮	flag: Côte d’Ivoire	country-flag
🇨🇰	flag: Cook Islands	country-flag
🇨🇱	flag: Chile	country-flag
🇨🇲	flag: Cameroon	country-flag
🇨🇳	flag: China	country-flag
🇨🇴	flag: Colombia	country-flag
🇨🇵	flag: Clipperton Island	country-flag
🇨🇶	flag: Sark	country-flag
🇨🇷	flag: Costa Rica	country-flag
🇨🇺	flag: Cuba	country-flag
🇨🇻	flag: Cape Verde	country-flag
🇨🇼	flag: Curaçao	country-flag
🇨🇽	flag: Christmas Island	country-flag
🇨🇾	flag: Cyprus	country-flag
🇨🇿	flag: Czechia	country-flag
🇩🇪	flag: Germany	country-flag
🇩🇬	flag: Diego Garcia	country-flag
🇩🇯	flag: Djibouti	country-flag
🇩🇰	flag: Denmark	country-flag
🇩🇲	flag: Dominica	country-flag
🇩🇴	flag: Dominican Republic	country-flag
🇩🇿	flag: Algeria	country-flag
🇪🇦	flag: Ceuta & Melilla	country-flag
🇪🇨	flag: Ecuador	country-flag
🇪🇪	flag: Estonia	country-flag
🇪🇬	flag: Egypt	country-flag
🇪🇭	flag: Western Sahara	country-flag
🇪🇷	flag: Eritrea	country-flag
🇪🇸	flag: Spain	country-flag
🇪🇹	flag: Ethiopia	country-flag
🇪🇺	flag: European Union	country-flag
🇫🇮	flag: Finland	country-flag
🇫🇯	flag: Fiji	country-flag
🇫🇰	flag: Falkland Islands	country-flag
🇫🇲	flag: Micronesia	country-flag
🇫🇴	flag: Faroe Islands	country-flag
🇫🇷	flag: France	country-flag
🇬🇦	flag: Gabon	country-flag
🇬🇧	flag: United Kingdom	country-flag
🇬🇩	flag: Grenada	country-flag
🇬🇪	flag: Georgia	country-flag
🇬🇫	flag: French Guiana	country-flag
🇬🇬	flag: Guernsey	country-flag
🇬🇭	flag: Ghana	country-flag
🇬🇮	flag: Gibraltar	country-flag
🇬🇱	flag: Greenland	country-flag
🇬🇲	flag: Gambia	country-flag
🇬🇳	flag: Guinea	country-flag
🇬🇵	flag: Guadeloupe	country-flag
🇬🇶	flag: Equatorial Guinea	country-flag
🇬🇷	flag: Greece	country-flag
🇬🇸	flag: South Georgia & South Sandwich Islands	country-flag
🇬🇹	flag: Guatemala	country-flag
🇬🇺	flag: Guam	country-flag
🇬🇼	flag: Guinea-Bissau	country-flag
🇬🇾	flag: Guyana	country-flag
🇭🇰	flag: Hong Kong SAR China	country-flag
🇭🇲	flag: Heard & McDonald Islands	country-flag
🇭🇳	flag: Honduras	country-flag
🇭🇷	flag: Croatia	country-flag
🇭🇹	flag: Haiti	country-flag
🇭🇺	flag: Hungary	country-flag
🇮🇨	flag: Canary Islands	country-flag
🇮🇩	flag: Indonesia	country-flag
🇮🇪	flag: Ireland	country-flag
🇮🇱	flag: Israel	country-flag
🇮🇲	flag: Isle of Man	country-flag
🇮🇳	flag: India	country-flag
🇮🇴	flag: British Indian Ocean Territory	country-flag
🇮🇶	flag: Iraq	country-flag
🇮🇷	flag: Iran	country-flag
🇮🇸	flag: Iceland	country-flag
🇮🇹	flag: Italy	country-flag
🇯🇪	flag: Jersey	country-flag
🇯🇲	flag: Jamaica	country-flag
🇯🇴	flag: Jordan	country-flag
🇯🇵	flag: Japan	country-flag
🇰🇪	flag: Kenya	country-flag
🇰🇬	flag: Kyrgyzstan	country-flag
🇰🇭	flag: Cambodia	country-flag
🇰🇮	flag: Kiribati	country-flag
🇰🇲	flag: Comoros	country-flag
🇰🇳	flag: St. Kitts & Nevis	country-flag
🇰🇵	flag: North Korea	country-flag
🇰🇷	flag: South Korea	country-flag
🇰🇼	flag: Kuwait	country-flag
🇰🇾	flag: Cayman Islands	country-flag
🇰🇿	flag: Kazakhstan	country-flag
🇱🇦	flag: Laos	country-flag
🇱🇧	flag: Lebanon	country-flag
🇱🇨	flag: St. Lucia	country-flag
🇱🇮	flag: Liechtenstein	country-flag
🇱🇰	flag: Sri Lanka	country-flag
🇱🇷	flag: Liberia	country-flag
🇱🇸	flag: Lesotho	country-flag
🇱🇹	flag: Lithuania	country-flag
🇱🇺	flag: Luxembourg	country-flag
🇱🇻	flag: Latvia	country-flag
🇱🇾	flag: Libya	country-flag
🇲🇦	flag: Morocco	country-flag
🇲🇨	flag: Monaco	country-flag
🇲🇩	flag: Moldova	country-flag
🇲🇪	flag: Montenegro	country-flag
🇲🇫	flag: St. Martin	country-flag
🇲🇬	flag: Madagascar	country-flag
🇲🇭	flag: Marshall Islands	country-flag
🇲🇰	flag: North Macedonia	country-flag
🇲🇱	flag: Mali	country-flag
🇲🇲	flag: Myanmar (Burma)	country-flag
🇲🇳	flag: Mongolia	country-flag
🇲🇴	flag: Macao SAR China	country-flag
🇲🇵	flag: Northern Mariana Islands	country-flag
🇲🇶	flag: Martinique	country-flag
🇲🇷	flag: Mauritania	country-flag
🇲🇸	flag: Montserrat	country-flag
🇲🇹	flag: Malta	country-flag
🇲🇺	flag: Mauritius	country-flag
🇲🇻	flag: Maldives	country-flag
🇲🇼	flag: Malawi	country-flag
🇲🇽	flag: Mexico	country-flag
🇲🇾	flag: Malaysia	country-flag
🇲🇿	flag: Mozambique	country-flag
🇳🇦	flag: Namibia	country-flag
🇳🇨	flag: New Caledonia	country-flag
🇳🇪	flag: Niger	country-flag
🇳🇫	flag: Norfolk Island	country-flag
🇳🇬	flag: Nigeria	country-flag
🇳🇮	flag: Nicaragua	country-flag
🇳🇱	flag: Netherlands	country-flag
🇳🇴	flag: Norway	country-flag
🇳🇵	flag: Nepal	country-flag
🇳🇷	flag: Nauru	country-flag
🇳🇺	flag: Niue	country-flag
🇳🇿	flag: New Zealand	country-flag
🇴🇲	flag: Oman	country-flag
🇵🇦	flag: Panama	country-flag
🇵🇪	flag: Peru	country-flag
🇵🇫	flag: French Polynesia	country-flag
🇵🇬	flag: Papua New Guinea	country-flag
🇵🇭	flag: Philippines	country-flag
🇵🇰	flag: Pakistan	country-flag
🇵🇱	flag: Poland	country-flag
🇵🇲	flag: St. Pierre & Miquelon	country-flag
🇵🇳	flag: Pitcairn Islands	country-flag
🇵🇷	flag: Puerto Rico	country-flag
🇵🇸	flag: Palestinian Territories	country-flag
🇵🇹	flag: Portugal	country-flag
🇵🇼	flag: Palau	country-flag
🇵🇾	flag: Paraguay	country-flag
🇶🇦	flag: Qatar	country-flag
🇷🇪	flag: Réunion	country-flag
🇷🇴	flag: Romania	country-flag
🇷🇸	flag: Serbia	country-flag
🇷🇺	flag: Russia	country-flag
🇷🇼	flag: Rwanda	country-flag
🇸🇦	flag: Saudi Arabia	country-flag
🇸🇧	flag: Solomon Islands	country-flag
🇸🇨	flag: Seychelles	country-flag
🇸🇩	flag: Sudan	country-flag
🇸🇪	flag: Sweden	country-flag
🇸🇬	flag: Singapore	country-flag
🇸🇭	flag: St. Helena	country-flag
🇸🇮	flag: Slovenia	country-flag
🇸🇯	flag: Svalbard & Jan Mayen	country-flag
🇸🇰	flag: Slovakia	country-flag
🇸🇱	flag: Sierra Leone	country-flag
🇸🇲	flag: San Marino	country-flag
🇸🇳	flag: Senegal	country-flag
🇸🇴	flag: Somalia	country-flag
🇸🇷	flag: Suriname	country-flag
🇸🇸	flag: South Sudan	country-flag
🇸🇹	flag: São Tomé & Príncipe	country-flag
🇸🇻	flag: El Salvador	country-flag
🇸🇽	flag: Sint Maarten	country-flag
🇸🇾	flag: Syria	country-flag
🇸🇿	flag: Eswatini	country-flag
🇹🇦	flag: Tristan da Cunha	country-flag
🇹🇨	flag: Turks & Caicos Islands	country-flag
🇹🇩	flag: Chad	country-flag
🇹🇫	flag: French Southern Territories	country-flag
🇹🇬	flag: Togo	country-flag
🇹🇭	flag: Thailand	country-flag
🇹🇯	flag: Tajikistan	country-flag
🇹🇰	flag: Tokelau	country-flag
🇹🇱	flag: Timor-Leste	country-flag
🇹🇲	flag: Turkmenistan	country-flag
🇹🇳	flag: Tunisia	country-flag
🇹🇴	flag: Tonga	country-flag
🇹🇷	flag: Türkiye	country-flag
🇹🇹	flag: Trinidad & Tobago	country-flag
🇹🇻	flag: Tuvalu	country-flag
🇹🇼	flag: Taiwan	country-flag
🇹🇿	flag: Tanzania	country-flag
🇺🇦	flag: Ukraine	country-flag
🇺🇬	flag: Uganda	country-flag
🇺🇲	flag: U.S. Outlying Islands	country-flag
🇺🇳	flag: United Nations	country-flag
🇺🇸	flag: United States	country-flag
🇺🇾	flag: Uruguay	country-flag
🇺🇿	flag: Uzbekistan	country-flag
🇻🇦	flag: Vatican City	country-flag
🇻🇨	flag: St. Vincent & Grenadines	country-flag
🇻🇪	flag: Venezuela	country-flag
🇻🇬	flag: British Virgin Islands	country-flag
🇻🇮	flag: U.S. Virgin Islands	country-flag
🇻🇳	flag: Vietnam	country-flag
🇻🇺	flag: Vanuatu	country-flag
🇼🇫	flag: Wallis & Futuna	country-flag
🇼🇸	flag: Samoa	country-flag
🇽🇰	flag: Kosovo	country-flag
🇾🇪	flag: Yemen	country-flag
🇾🇹	flag: Mayotte	country-flag
🇿🇦	flag: South Africa	country-flag
🇿🇲	flag: Zambia	country-flag
🇿🇼	flag: Zimbabwe	country-flag
🏴󠁧󠁢󠁥󠁮󠁧󠁿	flag: England	subdivision-flag
🏴󠁧󠁢󠁳󠁣󠁴󠁿	flag: Scotland	subdivision-flag
🏴󠁧󠁢󠁷󠁬󠁳󠁿	flag: Wales	subdivision-flag
"""#

    static let categories: [EmojiCatalogCategory] = {
        var result: [EmojiCatalogCategory] = []
        var currentName: String?
        var currentSymbol = "square.grid.2x2"
        var currentItems: [EmojiCatalogItem] = []

        func flushCurrentCategory() {
            guard let currentName else { return }
            result.append(EmojiCatalogCategory(name: currentName, symbolName: currentSymbol, items: currentItems))
            currentItems.removeAll(keepingCapacity: true)
        }

        for line in rawData.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.first == "@" {
                flushCurrentCategory()
                let header = line.dropFirst().split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
                currentName = header.indices.contains(0) ? String(header[0]) : "Emoji"
                currentSymbol = header.indices.contains(1) ? String(header[1]) : "square.grid.2x2"
                continue
            }

            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            currentItems.append(EmojiCatalogItem(value: String(parts[0]), name: String(parts[1]), subgroup: String(parts[2])))
        }

        flushCurrentCategory()
        return result
    }()

    static let searchItems: [(categoryName: String, item: EmojiCatalogItem)] = categories.flatMap { category in
        category.items.map { (category.name, $0) }
    }
}
