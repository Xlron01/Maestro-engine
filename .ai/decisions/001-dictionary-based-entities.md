# Decision 001: Dictionary-Based Entities for Custom Domain Objects

- **Date:** 2026-08-23
- **Status:** ACCEPTED

## Context
أثناء الانتقال لتفعيل عملاء الاستخبارات في Phase 6 Step 1، كنا بحاجة لتقرير كيفية استضافة الكيانات الجديدة غير الدولة (Agent / Agency) داخل `WorldState`. الخيارات المتاحة:
1. تحويل معمارية المحرك بالكامل إلى Entity Component System (ECS) أو تعريف كلاسات GDScript مخصصة لكل نوع كيان.
2. استخدام Generic Dictionaries مرتبطة بـ Entity IDs فريدة ومخزنة في قواميس عامة بـ `WorldState` مثل `agents` و `agencies`.

## Decision
تم اختيار **الخيار الثاني (Dictionary-Based Entities)** لكونه الأبسط والأسرع في التطوير، ويسمح بالاستخدام الكامل لآليات الـ Serialization القائمة (`to_dict` / `from_dict`) دون الحاجة لـ classes معقدة أو كسر التوافق مع ملفات الحفظ القديمة.

## Consequences
- تمثيل العملاء والوكالات بنجاح وحفظهم واستعادتهم دون تعديل هيكلي جوهري في المحرك.
- الحفاظ على كلاسات المحرك الأساسية خفيفة وسهلة الصيانة.

## Rejected Alternatives
- **ECS (Entity Component System):** تم رفضه مؤقتاً لكونه يمثل Overengineering مفرط في هذه المرحلة المبكرة وقبل ظهور مشاكل أداء حقيقية.
- **Custom Classes:** تم رفضه لتجنب تكرار كود الحفظ والاستعادة والـ Validation لكل نوع كائن جديد.
