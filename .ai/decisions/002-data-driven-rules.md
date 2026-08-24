# Decision 002: Data-Driven Rules & Global Weight Evaluation

- **Date:** 2026-08-20
- **Status:** ACCEPTED

## Context
أثناء العمل في Phase 1 و Phase 3، كنا بحاجة للتخلص من الأرقام والمعاملات المكتوبة يدوياً (Hardcoded values) داخل الكود لضمان مرونة المحرك وفصله التام عن القواعد السياسية للعبة.

## Decision
تم اتخاذ قرارين رئيسيين:
1. تجميع كافة المعاملات الرقمية وأوزان القرار في ملف بيانات خارجي `data/rules/politics.json` وتحميلها عبر الـ `ContentLoader`.
2. تصميم دالة موحدة عامة `evaluate_weighted_score` بـ `DecisionSystem.gd` تستخدم الأوزان من الـ `rules` parameter لحساب القرارات وتأثير الانقلابات وعمليات الاستخبارات دون الحاجة لكتابة كود تقييم موازٍ لكل ميزة جديدة.

## Consequences
- أصبح المحرك بالكامل مدفوعاً بالبيانات (Data-Driven).
- إمكانية تعديل أوزان نجاح الانقلابات أو استخبارات العمليات وتغير السلوك فوراً من ملف الـ JSON دون لمس كود GDScript.
- تسجيل المعاملات في `ContentSchema.gd` لمنع التجاهل التلقائي للمتغيرات.

## Rejected Alternatives
- **DSL (Domain Specific Language):** تم تأجيل بناء DSL كامل للقواعد لعدم وجود حاجة حقيقية له حالياً، وللحفاظ على بساطة المحرك.
