مواصفات تطوير وجه HERO وربطه بالصوت
قاعدة أساسية
تعديل نفس الشخصية الموجودة في assets/3d/sa7bi_hero.glb.
لا تنشئ شخصية ثانية ولا تستبدل المجسم بصورة ثابتة.
حافظ على الجسم والدرع والعباءة وشعار صاحبي AI وألوانهما.
حافظ على حركات الجسم الحالية كما هي: Hero_Idle وHero_Welcome وHero_Power.
الهوية البصرية
استخدم الصور المرجعية التي وفرها صاحب المشروع للوجه: وجه بيضاوي مائل للاستدارة، شعر داكن قصير، عينان داكنتان، حاجبان واضحان، أنف متوسط مستقيم، وابتسامة طبيعية. يجب أن تظل الشخصية نفسها بملابسها الحالية.
عناصر الوجه المطلوبة
أضف Shape Keys أو Morph Targets مستقلة للأسماء التالية:
eyeBlinkLeft, eyeBlinkRight
eyeWideLeft, eyeWideRight
browInnerUp, browDownLeft, browDownRight
browOuterUpLeft, browOuterUpRight
mouthSmileLeft, mouthSmileRight
mouthFrownLeft, mouthFrownRight
jawOpen, mouthClose, mouthPucker, mouthFunnel, cheekPuff
حركات التعبير التي يجب تصديرها كـGLB animations
هذه الأسماء عقد ثابت بين ملف Blender وتطبيق Flutter:
HERO_FACE_SMILE
HERO_FACE_SAD
HERO_FACE_SURPRISE
HERO_FACE_ANGRY
HERO_FACE_BLINK
التعبير المحايد هو وضع الراحة الافتراضي (كل أوزان الوجه صفر)، ولا يحتاج إلى حركة منفصلة.
حركات الفم (Visemes)
يجب تصدير حركة GLB مستقلة لكل اسم من الأسماء التالية:
HERO_VISEME_sil
HERO_VISEME_PP
HERO_VISEME_FF
HERO_VISEME_TH
HERO_VISEME_DD
HERO_VISEME_kk
HERO_VISEME_CH
HERO_VISEME_SS
HERO_VISEME_nn
HERO_VISEME_RR
HERO_VISEME_aa
HERO_VISEME_E
HERO_VISEME_I
HERO_VISEME_O
HERO_VISEME_U
اجعل كل حركة Viseme قصيرة (قرابة 0.12 إلى 0.22 ثانية)، تبدأ من الوضع المحايد وتعود إليه، وتتحكم في Morph Targets المناسبة دون تحريك الجسم أو تغيير ملامح الهوية.
متطلبات التصدير
سلّم ملف Blender قابلًا للتعديل .blend.
حدّث نفس الملف assets/3d/sa7bi_hero.glb مع تضمين الخامات والـMorph Targets والـAnimations داخله.
تأكد من بقاء حركات الجسم الثلاثة القديمة.
سلّم تقريرًا بأسماء وعدد Morph Targets وAnimations.
سلّم معاينة تتضمن المحايد والابتسامة والحزن والتعجب والغضب والرمش وعدة Visemes.
طريقة تشغيل التطبيق
يعتمد التطبيق على واجهة Model Viewer الرسمية:
حركة الجسم الأساسية تعمل عبر animationName.
تعبيرات الوجه تستخدم appendAnimation وdetachAnimation كحركات متداخلة، فلا توقف حركة الجسم.
خدمة Flutter TTS ترسل إشعارًا عند بداية الكلام وعند تقدم كل كلمة، ويستخدم التطبيق أول صوت واضح في الكلمة لاختيار حركة فم تقريبية.
تنبيه: إشعار Flutter TTS على Android يحدد تقدم الكلمة، وليس التوقيت الصوتي الدقيق لكل فونيم. لذلك هذا الربط مبدئي على مستوى الكلمات. لا تصف مزامنة الشفاه بأنها دقيقة لكل صوت قبل اختبارها بمصدر توقيت فونيمي مناسب.
شروط قبول النسخة
يفتح GLB في Model Viewer داخل التطبيق.
تعمل حركات الجسم الثلاث القديمة دون تغيير.
تظهر جميع أسماء الحركات الـ20 المطلوبة في قائمة Animations داخل GLB.
يتغير الوجه والفم فعليًا عند تشغيل حركات التعبير والفونيم.
لا توجد صورة ثابتة أو شخصية ثانية بدل المجسم.
