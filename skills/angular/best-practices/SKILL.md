---
name: angular-best-practices
description: Angular best practices covering performance, architecture, state management, and modern patterns. Use when building or optimizing Angular applications.
license: MIT
metadata:
  author: Community
  tags: angular, typescript, rxjs, performance, architecture
---

# Angular Best Practices

## Overview

Comprehensive guide for building performant, maintainable Angular applications using modern patterns, OnPush change detection, signals, and reactive programming with RxJS.

## When to Apply

Use these guidelines when:
- Building new Angular applications
- Optimizing existing Angular apps
- Implementing state management
- Working with reactive data streams
- Refactoring legacy Angular code

## Quick Reference

### OnPush Change Detection Strategy

**Impact**: CRITICAL - Significantly improves performance

**❌ Default (slower)**
```typescript
@Component({
  selector: 'app-user-list',
  template: `...`,
  // Default change detection runs on every event
})
export class UserListComponent {}
```

**✅ OnPush (faster)**
```typescript
@Component({
  selector: 'app-user-list',
  template: `
    <div *ngFor="let user of users$ | async">
      {{ user.name }}
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListComponent {
  users$ = this.userService.getUsers();
  
  constructor(private userService: UserService) {}
}
```

### Signals (Angular 16+)

**Impact**: HIGH - Simpler reactivity, better performance

**✅ Use Signals for local state**
```typescript
import { Component, signal, computed } from '@angular/core';

@Component({
  selector: 'app-counter',
  template: `
    <p>Count: {{ count() }}</p>
    <p>Double: {{ doubled() }}</p>
    <button (click)="increment()">+</button>
  `,
  standalone: true
})
export class CounterComponent {
  count = signal(0);
  doubled = computed(() => this.count() * 2);
  
  increment() {
    this.count.update(value => value + 1);
  }
}
```

### Standalone Components

**Impact**: HIGH - Reduces bundle size, simplifies architecture

**❌ Old: NgModules**
```typescript
@NgModule({
  declarations: [UserComponent],
  imports: [CommonModule, ReactiveFormsModule],
  exports: [UserComponent]
})
export class UserModule {}
```

**✅ New: Standalone**
```typescript
@Component({
  selector: 'app-user',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  template: `...`
})
export class UserComponent {}
```

### Reactive Forms

**Impact**: MEDIUM - Better type safety, testability

**✅ Strongly typed forms**
```typescript
interface UserForm {
  name: string;
  email: string;
  age: number;
}

@Component({
  selector: 'app-user-form',
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()">
      <input formControlName="name" />
      <input formControlName="email" type="email" />
      <input formControlName="age" type="number" />
      <button type="submit">Submit</button>
    </form>
  `
})
export class UserFormComponent {
  form = new FormGroup<{
    name: FormControl<string>;
    email: FormControl<string>;
    age: FormControl<number>;
  }>({
    name: new FormControl('', { nonNullable: true }),
    email: new FormControl('', { nonNullable: true }),
    age: new FormControl(0, { nonNullable: true })
  });
  
  onSubmit() {
    const value: UserForm = this.form.getRawValue();
    console.log(value);
  }
}
```

## RxJS Best Practices

### 1. Avoid Manual Subscriptions

**❌ Bad: Manual subscription management**
```typescript
export class UserComponent implements OnInit, OnDestroy {
  users: User[] = [];
  private subscription?: Subscription;
  
  ngOnInit() {
    this.subscription = this.userService.getUsers()
      .subscribe(users => this.users = users);
  }
  
  ngOnDestroy() {
    this.subscription?.unsubscribe();
  }
}
```

**✅ Good: Async pipe or takeUntilDestroyed**
```typescript
export class UserComponent {
  // Option 1: Async pipe (preferred)
  users$ = this.userService.getUsers();
  
  // Option 2: takeUntilDestroyed (Angular 16+)
  users: User[] = [];
  
  constructor(private userService: UserService) {
    this.userService.getUsers()
      .pipe(takeUntilDestroyed())
      .subscribe(users => this.users = users);
  }
}
```

### 2. Use RxJS Operators Effectively

**✅ Common patterns**
```typescript
// Debounce search input
searchControl.valueChanges.pipe(
  debounceTime(300),
  distinctUntilChanged(),
  switchMap(query => this.searchService.search(query))
).subscribe(results => this.results = results);

// Combine multiple streams
combineLatest([
  this.userService.getUser(),
  this.settingsService.getSettings()
]).pipe(
  map(([user, settings]) => ({ user, settings }))
).subscribe(data => this.data = data);

// Handle errors gracefully
this.apiService.getData().pipe(
  catchError(error => {
    console.error(error);
    return of([]);
  })
).subscribe(data => this.data = data);
```

### 3. Share Subscriptions

**❌ Bad: Multiple HTTP requests**
```typescript
const users$ = this.http.get<User[]>('/api/users');

users$.subscribe(/* ... */); // Request 1
users$.subscribe(/* ... */); // Request 2
```

**✅ Good: Share single request**
```typescript
const users$ = this.http.get<User[]>('/api/users').pipe(
  shareReplay(1)
);

users$.subscribe(/* ... */); // Request 1
users$.subscribe(/* ... */); // Uses cached result
```

## Performance Optimization

### 1. TrackBy Functions for ngFor

**Impact**: CRITICAL

**❌ Without trackBy**
```typescript
<div *ngFor="let item of items">{{ item.name }}</div>
```

**✅ With trackBy**
```typescript
<div *ngFor="let item of items; trackBy: trackById">
  {{ item.name }}
</div>

trackById(index: number, item: Item): number {
  return item.id;
}
```

### 2. Lazy Loading Routes

**Impact**: HIGH - Reduces initial bundle size

```typescript
const routes: Routes = [
  {
    path: 'users',
    loadComponent: () => import('./users/users.component')
      .then(m => m.UsersComponent)
  },
  {
    path: 'admin',
    loadChildren: () => import('./admin/admin.routes')
      .then(m => m.ADMIN_ROUTES)
  }
];
```

### 3. Virtual Scrolling for Large Lists

**Impact**: CRITICAL - Renders only visible items

```typescript
import { ScrollingModule } from '@angular/cdk/scrolling';

@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [ScrollingModule],
  template: `
    <cdk-virtual-scroll-viewport itemSize="50" class="viewport">
      <div *cdkVirtualFor="let user of users" class="item">
        {{ user.name }}
      </div>
    </cdk-virtual-scroll-viewport>
  `,
  styles: [`
    .viewport {
      height: 400px;
    }
    .item {
      height: 50px;
    }
  `]
})
export class UserListComponent {
  users = Array.from({ length: 10000 }, (_, i) => ({ 
    id: i, 
    name: `User ${i}` 
  }));
}
```

## Architecture Patterns

### 1. Smart vs Dumb Components

**Smart (Container) Components**:
- Manage state
- Handle business logic
- Communicate with services

**Dumb (Presentational) Components**:
- Receive data via @Input
- Emit events via @Output
- No service dependencies

```typescript
// Smart Component
@Component({
  selector: 'app-user-container',
  template: `
    <app-user-list 
      [users]="users$ | async"
      (userSelected)="onUserSelected($event)"
    />
  `
})
export class UserContainerComponent {
  users$ = this.userService.getUsers();
  
  constructor(private userService: UserService) {}
  
  onUserSelected(user: User) {
    this.router.navigate(['/users', user.id]);
  }
}

// Dumb Component
@Component({
  selector: 'app-user-list',
  template: `
    <div *ngFor="let user of users">
      <button (click)="userSelected.emit(user)">
        {{ user.name }}
      </button>
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class UserListComponent {
  @Input() users: User[] = [];
  @Output() userSelected = new EventEmitter<User>();
}
```

### 2. Service Layer Architecture

```typescript
// Data layer
@Injectable({ providedIn: 'root' })
export class UserApiService {
  constructor(private http: HttpClient) {}
  
  getUsers(): Observable<User[]> {
    return this.http.get<User[]>('/api/users');
  }
}

// Business logic layer
@Injectable({ providedIn: 'root' })
export class UserService {
  private usersSubject = new BehaviorSubject<User[]>([]);
  users$ = this.usersSubject.asObservable();
  
  constructor(private api: UserApiService) {
    this.loadUsers();
  }
  
  private loadUsers() {
    this.api.getUsers()
      .subscribe(users => this.usersSubject.next(users));
  }
  
  addUser(user: User) {
    const current = this.usersSubject.value;
    this.usersSubject.next([...current, user]);
  }
}
```

## State Management

### Option 1: Signals (Angular 16+)

```typescript
@Injectable({ providedIn: 'root' })
export class UserStore {
  private usersSignal = signal<User[]>([]);
  users = this.usersSignal.asReadonly();
  
  constructor(private api: UserApiService) {
    this.loadUsers();
  }
  
  private loadUsers() {
    this.api.getUsers()
      .subscribe(users => this.usersSignal.set(users));
  }
  
  addUser(user: User) {
    this.usersSignal.update(users => [...users, user]);
  }
}
```

### Option 2: NgRx (Complex apps)

Only use NgRx if you need:
- Time-travel debugging
- Complex state synchronization
- Multiple teams working on same state

For most apps, Signals or Services are sufficient.

## Common Pitfalls

### 1. Not Unsubscribing from Observables

Always use `async` pipe or `takeUntilDestroyed()`.

### 2. Mutating State Directly

```typescript
// ❌ Bad
this.users.push(newUser);

// ✅ Good
this.users = [...this.users, newUser];
```

### 3. Overusing NgModules

Prefer standalone components for new code.

### 4. Not Using Strict Mode

Enable in `tsconfig.json`:
```json
{
  "compilerOptions": {
    "strict": true,
    "strictTemplates": true
  }
}
```

## Testing Best Practices

```typescript
describe('UserComponent', () => {
  it('should display users', () => {
    const fixture = TestBed.createComponent(UserComponent);
    const component = fixture.componentInstance;
    
    component.users = [
      { id: 1, name: 'John' },
      { id: 2, name: 'Jane' }
    ];
    
    fixture.detectChanges();
    
    const compiled = fixture.nativeElement;
    expect(compiled.querySelectorAll('.user').length).toBe(2);
  });
});
```

## References

- [Angular Style Guide](https://angular.dev/style-guide)
- [RxJS Best Practices](https://rxjs.dev/guide/overview)
- [Angular Performance Checklist](https://web.dev/angular)

## Attribution

Community-curated best practices from Angular experts and official Angular documentation.
