# Testovací případy gramatik Pocket Realm. Použití: cases.sh <check-binárka> <adresář s *.gbnf>
set -euo pipefail
C="$1"; G="$2"
"$C" "$G/interpreter_quest.gbnf" \
 '+{"intent":"Prohledá kobku","category":"explore","stat":"duvtip","difficulty":"easy","risk":"low","items_used":[]}' \
 '+{"intent":"Útok \"mečem\"","category":"combat","stat":"sila","difficulty":"normal","risk":"medium","items_used":["Těžký meč","Lahev kořalky"]}' \
 '-{"intent":"x","category":"travel","stat":"sila","difficulty":"easy","risk":"low","items_used":[]}' \
 '-{"intent":"x","category":"combat","stat":"magie","difficulty":"easy","risk":"low","items_used":[]}' \
 '-{"intent":"x","category":"combat","stat":"sila","difficulty":"easy","risk":"low","items_used":[]} navíc'
"$C" "$G/interpreter_campaign.gbnf" \
 '+{"intent":"Pokračují","category":"travel","stat":"obratnost","difficulty":"normal","risk":"low","items_used":[]}' \
 '-{"intent":"x","category":"build","stat":"none","difficulty":"easy","risk":"none","items_used":[]}'
"$C" "$G/interpreter_realm.gbnf" \
 '+{"intent":"Staví farmu","category":"build","stat":"none","difficulty":"trivial","risk":"none","items_used":[],"build":"farma"}' \
 '+{"intent":"Hlídka","category":"explore","stat":"duvtip","difficulty":"easy","risk":"low","items_used":[],"build":"none"}' \
 '-{"intent":"x","category":"build","stat":"none","difficulty":"trivial","risk":"none","items_used":[]}' \
 '-{"intent":"x","category":"build","stat":"none","difficulty":"trivial","risk":"none","items_used":[],"build":"hrad"}'
"$C" "$G/narrator_quest.gbnf" \
 '+{"narration":"Tma.\nTicho \"jako\" v hrobě.","hp":-12,"stress":5,"gold":0,"items_gained":[{"name":"Rezavý klíč","kind":"key"}],"items_lost":[],"location":"Kobka","scene":"dungeon","chronicle":"Našla klíč.","objective_done":false}' \
 '-{"narration":"x","hp":0,"stress":0,"gold":0,"food":0,"items_gained":[],"items_lost":[],"location":"K","scene":"dungeon","chronicle":"c","objective_done":false}' \
 '-{"narration":"x","hp":1000,"stress":0,"gold":0,"items_gained":[],"items_lost":[],"location":"Ko","scene":"dungeon","chronicle":"c","objective_done":false}' \
 '-{ "narration":"x","hp":0,"stress":0,"gold":0,"items_gained":[],"items_lost":[],"location":"Ko","scene":"dungeon","chronicle":"c","objective_done":false}'
"$C" "$G/narrator_campaign.gbnf" \
 '+{"narration":"Vozy vrzají.","hp":0,"stress":3,"gold":-5,"food":-6,"pop":0,"defense":0,"morale":-2,"items_gained":[],"items_lost":["Lahev kořalky"],"location":"Brod","scene":"river","chronicle":"Přešli brod."}' \
 '-{"narration":"x","hp":0,"stress":0,"gold":0,"food":0,"pop":0,"defense":0,"morale":0,"items_gained":[{"name":"A","kind":"key"}],"items_lost":[],"location":"Brod","scene":"river","chronicle":"c"}' \
 '-{"narration":"x","hp":0,"stress":0,"gold":0,"food":0,"pop":0,"defense":0,"morale":0,"items_gained":[],"items_lost":[],"location":"Brod","scene":"vesmir","chronicle":"c"}'
"$C" "$G/narrator_realm.gbnf" \
 '+{"narration":"Osada žije.","hp":0,"stress":-3,"gold":10,"food":0,"pop":1,"defense":2,"morale":4,"items_gained":[{"name":"Rodový prsten","kind":"artifact"},{"name":"Lektvar","kind":"consumable"}],"items_lost":[],"location":"Náves","scene":"town","chronicle":"Den klidu.","resolve_threat":true}' \
 '-{"narration":"x","hp":0,"stress":0,"gold":0,"food":0,"pop":0,"defense":0,"morale":0,"items_gained":[{"name":"Aa","kind":"key"},{"name":"Bb","kind":"key"},{"name":"Cc","kind":"key"}],"items_lost":[],"location":"Ná","scene":"town","chronicle":"c","resolve_threat":true}'
"$C" "$G/story.gbnf" '+{"narration":"Vítej v temném kraji."}' '-{"narration":""}' '-{"text":"x"}'
echo "Gramatiky OK"
