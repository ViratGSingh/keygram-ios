import Foundation

// Text emoticons are compositional, so no finite standard can enumerate every
// possible form. This catalog covers the common Western emoticon and kaomoji
// families in a keyboard-friendly, categorized set.
enum KeyboardEmojiCatalog {
    private static let rawData = #"""
@Classic	text.bubble.fill
:)	smile	classic
:-)	smile with nose	classic
:D	big grin	classic
:-D	big grin with nose	classic
;)	wink	classic
;-)	wink with nose	classic
:P	tongue out	classic
:-P	tongue out with nose	classic
:p	playful	classic
;P	winking playful	classic
:3	cute smile	classic
:*	kiss	classic
:-*	kiss with nose	classic
:o	surprised	classic
:-o	surprised with nose	classic
:O	shocked	classic
:/	unsure	classic
:\	uncertain	classic
:|	neutral	classic
:-|	neutral with nose	classic
:(	sad	classic
:-(	sad with nose	classic
:'(	crying	classic
>:(	angry	classic
D:	dismayed	classic
DX	distressed	classic
XD	laughing	classic
xD	laughing	classic
B)	cool	classic
B-)	cool with nose	classic
8)	wide eyed smile	classic
O:)	angel	classic
0:)	angel	classic
>:)	devilish	classic
<3	heart	classic
</3	broken heart	classic
^_^	happy	classic
-_-	unimpressed	classic
o_O	confused	classic
O_O	shocked	classic
T_T	crying	classic
@Happy	face.smiling.fill
(^_^)	happy	happy
(^-^)	happy	happy
(^^)	happy	happy
(^.^)	happy	happy
(*^_^*)	happy blush	happy
(⌒▽⌒)	happy grin	happy
(⌒‿⌒)	happy	happy
(＾▽＾)	joyful	happy
(＾◡＾)	happy	happy
(￣▽￣)	satisfied	happy
(￣ω￣)	content	happy
(´∀`)	happy	happy
(´▽`)	happy	happy
(´ω`)	content	happy
(´• ω •`)	happy	happy
(◕‿◕)	happy	happy
(◠‿◠)	happy	happy
(◡‿◡)	peaceful	happy
(✿◠‿◠)	flower smile	happy
(◕ᴗ◕✿)	flower smile	happy
(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧	celebrating	happy
ヽ(・∀・)ﾉ	cheering	happy
ヽ(o＾▽＾o)ノ	joyful	happy
＼(＾▽＾)／	celebrating	happy
＼(^o^)／	cheering	happy
٩(◕‿◕｡)۶	excited	happy
٩(^ᴗ^)۶	excited	happy
ᕕ( ᐛ )ᕗ	happy walk	happy
ᕙ(^▿^-ᕙ)	feeling strong	happy
ᕦ(ò_óˇ)ᕤ	confident	happy
♪( ´▽｀)	singing	happy
♪(´▽｀)	happy tune	happy
ヾ(⌐■_■)ノ♪	dancing	happy
┌(・o・)┘♪	dancing	happy
♪└(・o・)┐	dancing	happy
d=(´▽｀)=b	great	happy
o(≧▽≦)o	delighted	happy
(๑˃ᴗ˂)ﻭ	excited	happy
(๑•̀ㅂ•́)و✧	ready	happy
☆*:.｡.o(≧▽≦)o.｡.:*☆	thrilled	happy
@Love	heart.fill
(♡‿♡)	in love	love
(♥ω♥*)	in love	love
(´♡‿♡`)	in love	love
(´∀｀)♡	love	love
(◕‿◕)♡	love	love
(｡♥‿♥｡)	in love	love
(づ￣ ³￣)づ	kiss	love
(っ˘з(˘⌣˘ )	kiss	love
( ˘ ³˘)♥	kiss	love
( ˘⌣˘)♡(˘⌣˘ )	loving	love
(´ε｀ )♡	kiss	love
(*¯ ³¯*)♡	kiss	love
♡( ◡‿◡ )	love	love
♡(｡- ω -)	love	love
♡ ～('▽^人)	affection	love
♡＼(￣▽￣)／♡	love	love
♥(ˆ⌣ˆԅ)	affection	love
(灬♥ω♥灬)	blushing love	love
(⁄ ⁄•⁄ω⁄•⁄ ⁄)	blushing	love
(⁄ ⁄>⁄ ▽ ⁄<⁄ ⁄)	shy love	love
(｡・//ε//・｡)	blushing	love
(´,,•ω•,,)♡	shy love	love
(っ´ω`)ﾉ(╥ω╥)	comforting	love
(つ≧▽≦)つ	hug	love
(づ｡◕‿‿◕｡)づ	hug	love
⊂(・▽・⊂)	hug	love
⊂(･ω･*⊂)	hug	love
(/^-^(^ ^*)/	hug	love
@Greeting	hand.wave.fill
(^_^)/	hello	greeting
(^-^*)/	hello	greeting
(￣▽￣)ノ	hello	greeting
( ´ ▽ ` )ﾉ	hello	greeting
(・∀・)ノ	hello	greeting
(o´ω`o)ﾉ	hello	greeting
(≧▽≦)/	hello	greeting
(｡･ω･)ﾉﾞ	hello	greeting
(＠´ー`)ﾉﾞ	hello	greeting
ヾ(☆▽☆)	hello	greeting
ヾ(・ω・*)	hello	greeting
ヾ(＾-＾)ノ	hello	greeting
ヾ(＾∇＾)	hello	greeting
ヾ(≧▽≦*)o	hello	greeting
＼(￣▽￣)／	hello	greeting
ヽ(>∀<☆)ノ	hello	greeting
ヽ(・ω・)ﾉ	hello	greeting
٩(｡•́‿•̀｡)۶	hello	greeting
(*・ω・)ﾉ	hello	greeting
|･ω･)ﾉ	peeking hello	greeting
|ω・)	peeking	greeting
|_・)	peeking	greeting
m(_ _)m	thank you	greeting
(_ _)	respect	greeting
(シ_ _)シ	bow	greeting
<(＿ ＿)>	bow	greeting
(￣^￣)ゞ	salute	greeting
(｀･ω･´)ゞ	salute	greeting
o7	salute	greeting
@Cute	sparkles
(・ω・)	cute	cute
(・`ω´・)	cute	cute
(´・ω・`)	cute	cute
(´• ᴗ •`)	cute	cute
(｡•́‿•̀｡)	cute	cute
(｡･ω･｡)	cute	cute
(｡・ω・｡)	cute	cute
(≧◡≦)	cute	cute
(◍•ᴗ•◍)	cute	cute
(◕ω◕)	cute	cute
(◕‿◕✿)	cute flower	cute
(✿◕‿◕)	cute flower	cute
(๑•ᴗ•๑)	cute	cute
(๑˘︶˘๑)	peaceful	cute
(๑´• .̫ •ू`๑)	cute	cute
(=^･ω･^=)	cute face	cute
(=^･^=)	cute face	cute
(ᵔᴥᵔ)	cute	cute
(•ө•)♡	cute love	cute
(❁´◡`❁)	cute flower	cute
(人 •͈ᴗ•͈)	please	cute
(づ｡◕‿‿◕｡)づ	cute hug	cute
ʕ•ᴥ•ʔ	cute	cute
ʕっ•ᴥ•ʔっ	cute hug	cute
ʕ￫ᴥ￩ʔ	cute	cute
ฅ^•ﻌ•^ฅ	cute	cute
UwU	cute	cute
uwu	cute	cute
OwO	curious cute	cute
owo	curious cute	cute
@Sad	cloud.rain.fill
(T_T)	crying	sad
(T_T)/~~~	crying goodbye	sad
(ToT)	crying	sad
(TT)	crying	sad
(ಥ﹏ಥ)	crying	sad
(ಥ_ಥ)	crying	sad
(╥﹏╥)	crying	sad
(╥_╥)	crying	sad
(;_;)	crying	sad
(；ω；)	crying	sad
(´；ω；`)	crying	sad
(ノ_<。)	crying	sad
(｡•́︿•̀｡)	sad	sad
(｡╯︵╰｡)	sad	sad
(︶︹︺)	sad	sad
(◞‸◟)	sad	sad
(◕︵◕)	sad	sad
(っ˘̩╭╮˘̩)っ	sad	sad
(μ_μ)	sad	sad
(ノД`)	crying	sad
(-_-;)	troubled	sad
(´-ω-`)	tired	sad
(´･ω･`)	deflated	sad
(´._.`)	disappointed	sad
(￣ヘ￣)	unhappy	sad
(个_个)	crying	sad
（；へ：）	crying	sad
｡ﾟ･ (>﹏<) ･ﾟ｡	crying	sad
。゜゜(´Ｏ`) ゜゜。	crying	sad
@Angry	flame.fill
(`Д´)	angry	angry
(`皿´＃)	angry	angry
( ` ω ´ )	angry	angry
(＃`Д´)	angry	angry
(＃＞＜)	angry	angry
(｀Д´)	angry	angry
(｀ε´)	annoyed	angry
(｀ー´)	annoyed	angry
(ಠ益ಠ)	angry	angry
(ಠ_ಠ)	disapproval	angry
(¬_¬)	annoyed	angry
(¬д¬。)	annoyed	angry
(눈_눈)	annoyed	angry
(；￣Д￣)	annoyed	angry
(￣へ￣)	annoyed	angry
(╬ಠ益ಠ)	very angry	angry
(凸ಠ益ಠ)凸	furious	angry
凸(￣ヘ￣)	furious	angry
ヽ(`Д´)ﾉ	angry	angry
ヽ(ಠ_ಠ)ノ	angry	angry
٩(╬ʘ益ʘ╬)۶	furious	angry
щ(ಠ益ಠщ)	furious	angry
щ(ﾟДﾟщ)	come on	angry
(ノಠ益ಠ)ノ彡┻━┻	table flip	angry
(╯°□°)╯︵ ┻━┻	table flip	angry
┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻	double table flip	angry
┬─┬ノ(ಠ_ಠノ)	put table back	angry
@Surprised	exclamationmark.circle.fill
(O_O)	shocked	surprised
(O.O)	shocked	surprised
(o_O)	confused surprise	surprised
(o.o)	surprised	surprised
(°ロ°) !	shocked	surprised
(⊙_⊙)	shocked	surprised
(⊙o⊙)	shocked	surprised
(☉_☉)	shocked	surprised
(゜ロ゜)	shocked	surprised
(ﾟДﾟ)	shocked	surprised
(ﾟoﾟ)	shocked	surprised
(ﾟДﾟ;)	shocked	surprised
(；゜０゜)	shocked	surprised
(￣□￣」)	shocked	surprised
(□_□)	shocked	surprised
(๑•́ ヮ •̀๑)	surprised	surprised
(ﾉﾟ0ﾟ)ﾉ~	shocked	surprised
Σ(ﾟДﾟ)	shocked	surprised
Σ(°△°|||)	shocked	surprised
Σ(゜゜)	shocked	surprised
Σ(O_O)	shocked	surprised
Σ(□_□)	shocked	surprised
ლ(ಠ_ಠ ლ)	what	surprised
@Confused	questionmark.circle.fill
(・・?)	confused	confused
(•ิ_•ิ)?	confused	confused
(⊙_☉)	confused	confused
(◎ ◎)ゞ	confused	confused
(￣ω￣;)	confused	confused
(￣～￣;)	thinking	confused
(・_・ヾ	confused	confused
(・・;)ゞ	confused	confused
(・・ ) ?	confused	confused
(・・;	confused	confused
(＠_＠)	confused	confused
(＠_＠;)	confused	confused
(ーー;)	confused	confused
(ー_ーゞ	confused	confused
(＃⌒∇⌒＃)ゞ	embarrassed	confused
(´･_･`)	confused	confused
(´･ω･`)?	confused	confused
(´-﹏-`；)	uneasy	confused
(´ε｀；)	uneasy	confused
(;￣ー￣川	nervous	confused
(^～^;)ゞ	awkward	confused
(⊙﹏⊙)	confused	confused
(￣.￣;)	unsure	confused
¯\_(ツ)_/¯	shrug	confused
┐(￣ヘ￣)┌	shrug	confused
┐('～`;)┌	shrug	confused
╮(￣ω￣;)╭	shrug	confused
╮( ˘ ､ ˘ )╭	shrug	confused
@Actions	arrow.triangle.2.circlepath
(－‸ლ)	facepalm	actions
(facepalm)	facepalm	actions
(ง'̀-'́)ง	fight	actions
(ง •̀_•́)ง	ready	actions
(งಠ_ಠ)ง	fight	actions
(つ▀¯▀)つ	hug	actions
(っ´▽`)っ	hug	actions
(っ・ω・)っ	hug	actions
(づ￣ ³￣)づ	hug	actions
⊂(・﹏・⊂)	hug	actions
⊂(◉‿◉)つ	hug	actions
ლ(・ヮ・ლ)	give	actions
ლ(╹◡╹ლ)	give	actions
(☞ﾟヮﾟ)☞	point right	actions
☜(ﾟヮﾟ☜)	point left	actions
☜(⌒▽⌒)☞	point both	actions
(☞ ͡° ͜ʖ ͡°)☞	pointing	actions
👉(ﾟヮﾟ👈)	pointing	actions
┬─┬ノ( º _ ºノ)	put table back	actions
┬──┬ ノ( ゜-゜ノ)	put table back	actions
(╯°□°）╯︵ ┻━┻	table flip	actions
┻━┻ミ＼(≧ﾛ≦＼)	table flip	actions
ε=ε=ε=┌(;*´Д`)ﾉ	running	actions
ε===(っ≧ω≦)っ	running	actions
ᕕ( ಠ‿ಠ)ᕗ	walking	actions
ᕕ(⌐■_■)ᕗ	walking	actions
(〜￣△￣)〜	dancing	actions
〜(꒪꒳꒪)〜	dancing	actions
ヘ(￣ω￣ヘ)	dancing	actions
(ノ^_^)ノ	dancing	actions
@Animals	pawprint.fill
(=^･ω･^=)	cat	animals
(=^･ｪ･^=)	cat	animals
(=①ω①=)	cat	animals
(=｀ω´=)	cat	animals
(=ＴェＴ=)	crying cat	animals
(=；ェ；=)	sad cat	animals
ฅ(•ㅅ•❀)ฅ	cat	animals
ฅ(＾・ω・＾ฅ)	cat	animals
ฅ^•ﻌ•^ฅ	cat	animals
(^・ω・^ )	cat	animals
ミ(・・)ミ	cat	animals
V●ᴥ●V	dog	animals
U・ᴥ・U	dog	animals
U＾ェ＾U	dog	animals
U・ﻌ・U	dog	animals
∪･ω･∪	dog	animals
ʕ•ᴥ•ʔ	bear	animals
ʕᵔᴥᵔʔ	bear	animals
ʕ￫ᴥ￩ʔ	bear	animals
ʕ •̀ o •́ ʔ	bear	animals
ʕっ•ᴥ•ʔっ	bear hug	animals
ᶘ ᵒᴥᵒᶅ	cat	animals
／(≧ x ≦)＼	rabbit	animals
／(･ × ･)＼	rabbit	animals
(•ө•)♡	bird	animals
@(・●・)@	koala	animals
くコ:彡	squid	animals
<・ )))><<	fish	animals
>°))))彡	fish	animals
"""#

    static let categories: [EmojiCatalogCategory] = {
        var result: [EmojiCatalogCategory] = []
        var currentName: String?
        var currentSymbol = "text.bubble.fill"
        var currentItems: [EmojiCatalogItem] = []

        func flushCurrentCategory() {
            guard let currentName else { return }
            result.append(
                EmojiCatalogCategory(
                    name: currentName,
                    symbolName: currentSymbol,
                    items: currentItems
                )
            )
            currentItems.removeAll(keepingCapacity: true)
        }

        for line in rawData.split(separator: "\n", omittingEmptySubsequences: true) {
            if line.first == "@" {
                flushCurrentCategory()
                let header = line.dropFirst().split(
                    separator: "\t",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )
                currentName = header.indices.contains(0) ? String(header[0]) : "Keyboard Emoji"
                currentSymbol = header.indices.contains(1) ? String(header[1]) : "text.bubble.fill"
                continue
            }

            let parts = line.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            currentItems.append(
                EmojiCatalogItem(
                    value: String(parts[0]),
                    name: String(parts[1]),
                    subgroup: String(parts[2])
                )
            )
        }

        flushCurrentCategory()
        return result
    }()

    static let searchItems: [(categoryName: String, item: EmojiCatalogItem)] = categories.flatMap { category in
        category.items.map { (category.name, $0) }
    }
}
