# Polymorphism Implementation Plan: Extending to Toys

## Overview
Extend The Giving Shelf to support both books and toys using polymorphic associations. This allows sharing the request and availability logic between both item types while maintaining separate models for type-specific attributes.

## Architecture Decision: Separate Tables with Polymorphism

**Approach**: Use separate `books` and `toys` tables with polymorphic associations for shared functionality.

**Rationale**:
- Books and toys have different attributes (books: author, ISBN, published_year; toys: brand, age_range, etc.)
- Cleaner separation of concerns
- Easier to extend with more item types in the future
- Type-specific validations and business logic stay separate

## Migration Execution Order

### 1. Create ShareableItemStatus model (keep BookStatus alias)
### 2. Create ShareableItem concern
### 3. Create toys table migration
### 4. Rename book_requests → item_requests (with data migration)
### 5. Rename group_book_availabilities → group_item_availabilities (with data migration)
### 6. Update Book model to include ShareableItem
### 7. Create Toy model
### 8. Create ItemRequest model (keep BookRequest alias)
### 9. Create GroupItemAvailability model (keep GroupBookAvailability alias)
### 10. Update User model
### 11. Update CommunityGroup model
### 12. Create ShareableItemService
### 13. Update BookService
### 14. Create ToyService
### 15. Update ItemRequestService (keep BookRequestService alias)
### 16. Update controllers
### 17. Create ToysController
### 18. Update routes
### 19. Update frontend 
### 20. Update ActiveAdmin
### 21. Update tests
### 22. Run full test suite
### 23. Remove backward compatibility aliases (after everything works)

### Important Notes
- Keep backward compatibility aliases during migration to avoid breaking existing code
- Test thoroughly before removing aliases
- Update all JavaScript/frontend code to use new endpoints
- Update sitemap generator to include toys
- Consider adding a shared "Items" view that shows both books and toys together
- Update email templates to reference "items" instead of just "books"
- Update all user-facing strings to be more generic where appropriate

### Rollback Plan
If issues arise:
### 1. Keep migrations reversible (all migrations include down methods)
### 2. Keep backward compatibility aliases until migration is fully tested
### 3. Can rollback individual migrations if needed
### 4. Database backups before major migrations

### Post-Migration Cleanup
After successful migration and testing:
### 1. Remove BookRequest = ItemRequest alias
### 2. Remove GroupBookAvailability = GroupItemAvailability alias
### 3. Remove BookStatus = ShareableItemStatus alias
### 4. Remove BookRequestService = ItemRequestService alias
### 5. Update all remaining references in codebase
### 6. Remove old migration files (optional, keep for history)