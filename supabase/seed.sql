-- Lango — starter content (small, high-quality dataset).
-- Run after 0001_initial_schema.sql.

insert into public.languages (code, name) values
  ('ko', 'Korean'),
  ('ja', 'Japanese')
on conflict (code) do nothing;

-- ── Korean vocabulary ────────────────────────────────────────────────────────
insert into public.vocabulary
  (language, word, romanization, translation, part_of_speech, difficulty, example_native, example_translation) values
  ('ko', '먹다', 'meokda', 'to eat', 'verb', 1, '밥을 먹다', 'to eat a meal'),
  ('ko', '가다', 'gada', 'to go', 'verb', 1, '학교에 가다', 'to go to school'),
  ('ko', '오다', 'oda', 'to come', 'verb', 1, '친구가 오다', 'a friend comes'),
  ('ko', '보다', 'boda', 'to see / to watch', 'verb', 1, '책을 보다', 'to look at a book'),
  ('ko', '하다', 'hada', 'to do', 'verb', 1, '공부를 하다', 'to do studying'),
  ('ko', '있다', 'itda', 'to exist / to have', 'verb', 1, '시간이 있다', 'to have time'),
  ('ko', '없다', 'eopda', 'to not exist / to not have', 'verb', 1, '시간이 없다', 'to not have time'),
  ('ko', '좋다', 'jota', 'to be good', 'adjective', 1, '날씨가 좋다', 'the weather is good'),
  ('ko', '크다', 'keuda', 'to be big', 'adjective', 1, '집이 크다', 'the house is big'),
  ('ko', '작다', 'jakda', 'to be small', 'adjective', 1, '집이 작다', 'the house is small'),
  ('ko', '물', 'mul', 'water', 'noun', 1, '물을 마셔요', 'I drink water'),
  ('ko', '밥', 'bap', 'rice / meal', 'noun', 1, '밥을 먹어요', 'I eat a meal'),
  ('ko', '집', 'jip', 'house / home', 'noun', 1, '집에 가요', 'I go home'),
  ('ko', '학교', 'hakgyo', 'school', 'noun', 1, '학교에 가요', 'I go to school'),
  ('ko', '친구', 'chingu', 'friend', 'noun', 1, '친구를 만나요', 'I meet a friend'),
  ('ko', '책', 'chaek', 'book', 'noun', 1, '책을 읽어요', 'I read a book'),
  ('ko', '사람', 'saram', 'person', 'noun', 1, '좋은 사람', 'a good person'),
  ('ko', '시간', 'sigan', 'time', 'noun', 1, '시간이 없어요', 'I have no time'),
  ('ko', '오늘', 'oneul', 'today', 'noun', 1, '오늘 뭐 해요?', 'What are you doing today?'),
  ('ko', '내일', 'naeil', 'tomorrow', 'noun', 1, '내일 만나요', 'See you tomorrow'),
  ('ko', '어제', 'eoje', 'yesterday', 'noun', 1, '어제 학교에 갔어요', 'I went to school yesterday'),
  ('ko', '안녕하세요', 'annyeonghaseyo', 'hello', 'expression', 1, null, null),
  ('ko', '감사합니다', 'gamsahamnida', 'thank you', 'expression', 1, null, null),
  ('ko', '네', 'ne', 'yes', 'expression', 1, null, null),
  ('ko', '아니요', 'aniyo', 'no', 'expression', 1, null, null),
  ('ko', '이름', 'ireum', 'name', 'noun', 1, '이름이 뭐예요?', 'What is your name?'),
  ('ko', '사랑', 'sarang', 'love', 'noun', 2, '사랑해요', 'I love you'),
  ('ko', '한국어', 'hangugeo', 'Korean language', 'noun', 1, '한국어를 공부해요', 'I study Korean'),
  ('ko', '일본어', 'ilboneo', 'Japanese language', 'noun', 1, '일본어를 공부해요', 'I study Japanese'),
  ('ko', '공부하다', 'gongbuhada', 'to study', 'verb', 1, '한국어를 공부하다', 'to study Korean')
on conflict (language, word, translation) do nothing;

-- ── Japanese vocabulary ──────────────────────────────────────────────────────
insert into public.vocabulary
  (language, word, romanization, translation, part_of_speech, difficulty, example_native, example_translation) values
  ('ja', '食べる', 'taberu', 'to eat', 'verb', 1, 'ご飯を食べる', 'to eat a meal'),
  ('ja', '行く', 'iku', 'to go', 'verb', 1, '学校に行く', 'to go to school'),
  ('ja', '来る', 'kuru', 'to come', 'verb', 1, '友達が来る', 'a friend comes'),
  ('ja', '見る', 'miru', 'to see / to watch', 'verb', 1, '映画を見る', 'to watch a movie'),
  ('ja', 'する', 'suru', 'to do', 'verb', 1, '勉強をする', 'to do studying'),
  ('ja', 'ある', 'aru', 'to exist (things)', 'verb', 1, '時間がある', 'to have time'),
  ('ja', 'いる', 'iru', 'to exist (people/animals)', 'verb', 1, '猫がいる', 'there is a cat'),
  ('ja', 'いい', 'ii', 'good', 'adjective', 1, '天気がいい', 'the weather is good'),
  ('ja', '大きい', 'ookii', 'big', 'adjective', 1, '家が大きい', 'the house is big'),
  ('ja', '小さい', 'chiisai', 'small', 'adjective', 1, '家が小さい', 'the house is small'),
  ('ja', '水', 'mizu', 'water', 'noun', 1, '水を飲みます', 'I drink water'),
  ('ja', 'ご飯', 'gohan', 'rice / meal', 'noun', 1, 'ご飯を食べます', 'I eat a meal'),
  ('ja', '家', 'ie', 'house / home', 'noun', 1, '家に帰ります', 'I go home'),
  ('ja', '学校', 'gakkou', 'school', 'noun', 1, '学校に行きます', 'I go to school'),
  ('ja', '友達', 'tomodachi', 'friend', 'noun', 1, '友達に会います', 'I meet a friend'),
  ('ja', '本', 'hon', 'book', 'noun', 1, '本を読みます', 'I read a book'),
  ('ja', '人', 'hito', 'person', 'noun', 1, 'いい人', 'a good person'),
  ('ja', '時間', 'jikan', 'time', 'noun', 1, '時間がありません', 'I have no time'),
  ('ja', '今日', 'kyou', 'today', 'noun', 1, '今日は何をしますか', 'What are you doing today?'),
  ('ja', '明日', 'ashita', 'tomorrow', 'noun', 1, 'また明日', 'See you tomorrow'),
  ('ja', '昨日', 'kinou', 'yesterday', 'noun', 1, '昨日学校に行きました', 'I went to school yesterday'),
  ('ja', 'こんにちは', 'konnichiwa', 'hello', 'expression', 1, null, null),
  ('ja', 'ありがとう', 'arigatou', 'thank you', 'expression', 1, null, null),
  ('ja', 'はい', 'hai', 'yes', 'expression', 1, null, null),
  ('ja', 'いいえ', 'iie', 'no', 'expression', 1, null, null),
  ('ja', '名前', 'namae', 'name', 'noun', 1, 'お名前は何ですか', 'What is your name?'),
  ('ja', '愛', 'ai', 'love', 'noun', 2, '愛しています', 'I love you'),
  ('ja', '韓国語', 'kankokugo', 'Korean language', 'noun', 1, '韓国語を勉強します', 'I study Korean'),
  ('ja', '日本語', 'nihongo', 'Japanese language', 'noun', 1, '日本語を勉強します', 'I study Japanese'),
  ('ja', '勉強する', 'benkyou suru', 'to study', 'verb', 1, '日本語を勉強する', 'to study Japanese')
on conflict (language, word, translation) do nothing;

-- ── Grammar points + examples ────────────────────────────────────────────────
with g as (
  insert into public.grammar_points (language, name, meaning, explanation, difficulty) values
    ('ko', '-아/어 주세요', 'Please do...', 'Attach -아/어 주세요 to a verb stem to politely ask someone to do something for you. Verbs whose last vowel is ㅏ/ㅗ take -아 주세요; the rest take -어 주세요.', 1),
    ('ko', '은/는', 'Topic particle', 'Marks the topic of the sentence — what the sentence is about. Use 은 after a consonant and 는 after a vowel. Often contrasts with something else.', 1),
    ('ko', '이/가', 'Subject particle', 'Marks the grammatical subject. Use 이 after a consonant and 가 after a vowel. Emphasizes who or what is doing the action, or introduces new information.', 1),
    ('ko', '-고 싶다', 'Want to...', 'Attach -고 싶다 to a verb stem to express what the speaker wants to do. In polite speech, use -고 싶어요.', 1),
    ('ko', '-았/었어요', 'Past tense (polite)', 'Attach -았어요 (after ㅏ/ㅗ vowels) or -었어요 (after other vowels) to the verb stem to make the polite past tense.', 1),
    ('ja', '〜てください', 'Please...', 'Attach ください to the verb''s て-form to politely ask someone to do something.', 1),
    ('ja', 'は', 'Topic particle', 'Marks the topic of the sentence — what the sentence is about. Written は but pronounced "wa" as a particle.', 1),
    ('ja', 'が', 'Subject particle', 'Marks the grammatical subject. Emphasizes who or what does the action, or introduces new information.', 1),
    ('ja', '〜たい', 'Want to...', 'Attach たい to the verb''s ます-stem to express what the speaker wants to do. Conjugates like an い-adjective.', 1),
    ('ja', '〜ました', 'Past tense (polite)', 'Replace ます with ました to make the polite past tense of a verb.', 1)
  returning id, language, name
)
insert into public.grammar_examples (grammar_point_id, native, translation, sort_order)
select g.id, e.native, e.translation, e.sort_order
from g
join (values
  ('ko', '-아/어 주세요', '도와 주세요.', 'Please help me.', 0),
  ('ko', '-아/어 주세요', '기다려 주세요.', 'Please wait.', 1),
  ('ko', '은/는', '저는 학생이에요.', 'I am a student.', 0),
  ('ko', '은/는', '오늘은 날씨가 좋아요.', 'As for today, the weather is good.', 1),
  ('ko', '이/가', '비가 와요.', 'It is raining.', 0),
  ('ko', '이/가', '친구가 왔어요.', 'A friend came.', 1),
  ('ko', '-고 싶다', '먹고 싶어요.', 'I want to eat.', 0),
  ('ko', '-고 싶다', '한국에 가고 싶어요.', 'I want to go to Korea.', 1),
  ('ko', '-았/었어요', '학교에 갔어요.', 'I went to school.', 0),
  ('ko', '-았/었어요', '밥을 먹었어요.', 'I ate a meal.', 1),
  ('ja', '〜てください', '待ってください。', 'Please wait.', 0),
  ('ja', '〜てください', '助けてください。', 'Please help me.', 1),
  ('ja', 'は', '私は学生です。', 'I am a student.', 0),
  ('ja', 'は', '今日は天気がいいです。', 'As for today, the weather is good.', 1),
  ('ja', 'が', '雨が降っています。', 'It is raining.', 0),
  ('ja', 'が', '友達が来ました。', 'A friend came.', 1),
  ('ja', '〜たい', '食べたいです。', 'I want to eat.', 0),
  ('ja', '〜たい', '日本に行きたいです。', 'I want to go to Japan.', 1),
  ('ja', '〜ました', '学校に行きました。', 'I went to school.', 0),
  ('ja', '〜ました', 'ご飯を食べました。', 'I ate a meal.', 1)
) as e(language, name, native, translation, sort_order)
  on e.language = g.language and e.name = g.name;

-- ── Hangul ───────────────────────────────────────────────────────────────────
insert into public.characters
  (language, script, character, romanization, pronunciation_hint, example_word, example_translation, sort_order) values
  ('ko', 'hangul_consonant', 'ㄱ', 'g/k', 'like g in "go"', '가방', 'bag', 1),
  ('ko', 'hangul_consonant', 'ㄴ', 'n', 'like n in "no"', '나무', 'tree', 2),
  ('ko', 'hangul_consonant', 'ㄷ', 'd/t', 'like d in "dog"', '다리', 'leg / bridge', 3),
  ('ko', 'hangul_consonant', 'ㄹ', 'r/l', 'between r and l', '라면', 'ramen', 4),
  ('ko', 'hangul_consonant', 'ㅁ', 'm', 'like m in "mom"', '물', 'water', 5),
  ('ko', 'hangul_consonant', 'ㅂ', 'b/p', 'like b in "boy"', '밥', 'rice / meal', 6),
  ('ko', 'hangul_consonant', 'ㅅ', 's', 'like s in "sun"', '사람', 'person', 7),
  ('ko', 'hangul_consonant', 'ㅇ', 'ng / silent', 'silent at the start, "ng" at the end of a syllable', '아기', 'baby', 8),
  ('ko', 'hangul_consonant', 'ㅈ', 'j', 'like j in "jam"', '자다', 'to sleep', 9),
  ('ko', 'hangul_consonant', 'ㅊ', 'ch', 'like ch in "chair"', '차', 'tea / car', 10),
  ('ko', 'hangul_consonant', 'ㅋ', 'k', 'aspirated k', '코', 'nose', 11),
  ('ko', 'hangul_consonant', 'ㅌ', 't', 'aspirated t', '토끼', 'rabbit', 12),
  ('ko', 'hangul_consonant', 'ㅍ', 'p', 'aspirated p', '팔', 'arm', 13),
  ('ko', 'hangul_consonant', 'ㅎ', 'h', 'like h in "hat"', '하늘', 'sky', 14),
  ('ko', 'hangul_vowel', 'ㅏ', 'a', 'like a in "father"', '아기', 'baby', 15),
  ('ko', 'hangul_vowel', 'ㅑ', 'ya', 'like ya in "yard"', '야구', 'baseball', 16),
  ('ko', 'hangul_vowel', 'ㅓ', 'eo', 'like u in "up"', '어머니', 'mother', 17),
  ('ko', 'hangul_vowel', 'ㅕ', 'yeo', 'like yu in "yummy"', '여자', 'woman', 18),
  ('ko', 'hangul_vowel', 'ㅗ', 'o', 'like o in "go"', '오이', 'cucumber', 19),
  ('ko', 'hangul_vowel', 'ㅛ', 'yo', 'like yo in "yoga"', '요리', 'cooking', 20),
  ('ko', 'hangul_vowel', 'ㅜ', 'u', 'like oo in "moon"', '우유', 'milk', 21),
  ('ko', 'hangul_vowel', 'ㅠ', 'yu', 'like you', '유리', 'glass', 22),
  ('ko', 'hangul_vowel', 'ㅡ', 'eu', 'like u with lips spread flat', '그림', 'picture', 23),
  ('ko', 'hangul_vowel', 'ㅣ', 'i', 'like ee in "see"', '이름', 'name', 24)
on conflict (language, script, character) do nothing;

-- ── Hiragana ─────────────────────────────────────────────────────────────────
insert into public.characters (language, script, character, romanization, sort_order) values
  ('ja','hiragana','あ','a',1),('ja','hiragana','い','i',2),('ja','hiragana','う','u',3),('ja','hiragana','え','e',4),('ja','hiragana','お','o',5),
  ('ja','hiragana','か','ka',6),('ja','hiragana','き','ki',7),('ja','hiragana','く','ku',8),('ja','hiragana','け','ke',9),('ja','hiragana','こ','ko',10),
  ('ja','hiragana','さ','sa',11),('ja','hiragana','し','shi',12),('ja','hiragana','す','su',13),('ja','hiragana','せ','se',14),('ja','hiragana','そ','so',15),
  ('ja','hiragana','た','ta',16),('ja','hiragana','ち','chi',17),('ja','hiragana','つ','tsu',18),('ja','hiragana','て','te',19),('ja','hiragana','と','to',20),
  ('ja','hiragana','な','na',21),('ja','hiragana','に','ni',22),('ja','hiragana','ぬ','nu',23),('ja','hiragana','ね','ne',24),('ja','hiragana','の','no',25),
  ('ja','hiragana','は','ha',26),('ja','hiragana','ひ','hi',27),('ja','hiragana','ふ','fu',28),('ja','hiragana','へ','he',29),('ja','hiragana','ほ','ho',30),
  ('ja','hiragana','ま','ma',31),('ja','hiragana','み','mi',32),('ja','hiragana','む','mu',33),('ja','hiragana','め','me',34),('ja','hiragana','も','mo',35),
  ('ja','hiragana','や','ya',36),('ja','hiragana','ゆ','yu',37),('ja','hiragana','よ','yo',38),
  ('ja','hiragana','ら','ra',39),('ja','hiragana','り','ri',40),('ja','hiragana','る','ru',41),('ja','hiragana','れ','re',42),('ja','hiragana','ろ','ro',43),
  ('ja','hiragana','わ','wa',44),('ja','hiragana','を','wo',45),('ja','hiragana','ん','n',46)
on conflict (language, script, character) do nothing;

-- ── Katakana ─────────────────────────────────────────────────────────────────
insert into public.characters (language, script, character, romanization, sort_order) values
  ('ja','katakana','ア','a',101),('ja','katakana','イ','i',102),('ja','katakana','ウ','u',103),('ja','katakana','エ','e',104),('ja','katakana','オ','o',105),
  ('ja','katakana','カ','ka',106),('ja','katakana','キ','ki',107),('ja','katakana','ク','ku',108),('ja','katakana','ケ','ke',109),('ja','katakana','コ','ko',110),
  ('ja','katakana','サ','sa',111),('ja','katakana','シ','shi',112),('ja','katakana','ス','su',113),('ja','katakana','セ','se',114),('ja','katakana','ソ','so',115),
  ('ja','katakana','タ','ta',116),('ja','katakana','チ','chi',117),('ja','katakana','ツ','tsu',118),('ja','katakana','テ','te',119),('ja','katakana','ト','to',120),
  ('ja','katakana','ナ','na',121),('ja','katakana','ニ','ni',122),('ja','katakana','ヌ','nu',123),('ja','katakana','ネ','ne',124),('ja','katakana','ノ','no',125),
  ('ja','katakana','ハ','ha',126),('ja','katakana','ヒ','hi',127),('ja','katakana','フ','fu',128),('ja','katakana','ヘ','he',129),('ja','katakana','ホ','ho',130),
  ('ja','katakana','マ','ma',131),('ja','katakana','ミ','mi',132),('ja','katakana','ム','mu',133),('ja','katakana','メ','me',134),('ja','katakana','モ','mo',135),
  ('ja','katakana','ヤ','ya',136),('ja','katakana','ユ','yu',137),('ja','katakana','ヨ','yo',138),
  ('ja','katakana','ラ','ra',139),('ja','katakana','リ','ri',140),('ja','katakana','ル','ru',141),('ja','katakana','レ','re',142),('ja','katakana','ロ','ro',143),
  ('ja','katakana','ワ','wa',144),('ja','katakana','ヲ','wo',145),('ja','katakana','ン','n',146)
on conflict (language, script, character) do nothing;
