# AGENTS.md — Bootstrap Protocol & Entry Point

> [!IMPORTANT]
> **قاعدة إلزامية:** يجب على أي نموذج ذكاء اصطناعي (AI Agent) يبدأ العمل على هذا المستودع قراءة هذا المستند أولاً واتباع بروتوكول التشغيل حرفياً.

---

## 1) Agent Bootstrap Protocol

عند استلاف أي مهمة في هذا المشروع، يجب اتباع الخطوات التتابعية التالية بدقة:

```text
                  START (مرحلة الاستلام)
                     │
                     ▼
             1. اقرأ AGENTS.md (هذا الملف)
                     │
                     ▼
          2. اقرأ .ai/constitution.md (الدستور والقواعد)
                     │
                     ▼
       3. اقرأ .ai/state.md + .ai/tasks/active.md
            (تحديد حالة المشروع والمهمة الحالية)
                     │
                     ▼
       4. اقرأ .ai/context-map.md (تحديد نطاق العمل)
                     │
                     ▼
       5. اقرأ مستندات المعمارية والقرارات ذات الصلة
          (.ai/architecture.md + .ai/decisions/)
                     │
                     ▼
             6. ابدأ التنفيذ (IMPLEMENT)
                     │
                     ▼
              7. اختبر (TEST)
                     │
             ┌───────┴───────┐
             ▼               ▼
           FAIL             PASS
             │               │
             ▼               ▼
          8. صلح      9. وثّق الأدلة (evidence/tests/)
                             │
                             ▼
                      10. حدّث ملفات الذاكرة
                          (state.md + CHANGELOG.md + tasks/)
                             │
                             ▼
                      11. شغّل سكريبت التحقق
                          (python scripts/validate_memory.py)
                             │
                             ▼
                      12. راجع git diff ثم Handoff
                             │
                             ▼
                           COMMIT
```

---

## 2) Quick Directory Index

- **دستور العمل:** [.ai/constitution.md](file:///.ai/constitution.md)
- **بروتوكول صيغة الملفات:** [.ai/memory-protocol.md](file:///.ai/memory-protocol.md)
- **خريطة المكونات والأكواد:** [.ai/context-map.md](file:///.ai/context-map.md)
- **المهام النشطة:** [.ai/tasks/active.md](file:///.ai/tasks/active.md)
- **الحالة الحالية:** [.ai/state.md](file:///.ai/state.md)
- **سجل التسليم والتسلم الأحدث:** [.ai/handoffs/latest.md](file:///.ai/handoffs/latest.md)
- **سكريبت التحقق الآلي:** [scripts/validate_memory.py](file:///scripts/validate_memory.py)

---

## 3) Non-Negotiable Instructions

1. **الـ Chat History لا يُمثّل مرجعية:** الكود الفعلي وملفات الذاكرة في المستودع هي مصدر الحقيقة الوحيد.
2. **ممنوع تزييف الأدلة:** نجاح الاختبارات يتطلب حفظ الـ raw output الفعلي داخل مجلد الأدلة [.ai/evidence/tests/](file:///.ai/evidence/tests/) والإشارة إليه صراحة بـ file path.
3. **لا تكمل المهمة دون التحقق الآلي:** تشغيل `python scripts/validate_memory.py` إلزامي قبل تسليم المهمة.
4. **الالتزام بالـ Commit الذاتي:** يجب على الـ AI القيام بعمل Git Commit بنفسه لحفظ تقدم العمل مباشرة بعد نجاح الفحص والتحقق وتحديث مستندات الذاكرة.
