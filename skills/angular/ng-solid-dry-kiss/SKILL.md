---
name: ng-solid-dry-kiss
description: Applies SOLID, DRY, and KISS principles to Angular TypeScript code: single responsibility services and components, open/closed directives and pipes, dependency inversion via interfaces, eliminating duplicated interceptors and resolvers, and avoiding over-engineering. Trigger: When user asks to refactor, review, or architect clean Angular code following software engineering principles.
license: Apache-2.0
metadata:
  author: deuna
  version: "1.0"
  scope: [angular]
  auto_invoke: "Refactoring or reviewing Angular code for clean architecture"
allowed-tools: Read, Write, Bash, Glob
---

# Angular SOLID · DRY · KISS

> Los mismos principios universales, aplicados a los patrones específicos de Angular:
> componentes, servicios, directivas, pipes, y el sistema de inyección de dependencias.

## When to Use

- Usuario pide refactorizar un servicio o componente que "creció demasiado"
- Servicio que mezcla HTTP, lógica de negocio y transformación de datos
- Lógica de guards, interceptors o resolvers duplicada entre módulos
- Componente con demasiados `@Input`s o con lógica compleja en el template
- Code review donde se detectan violaciones de estos principios en Angular

---

## SOLID en Angular

### S — Single Responsibility

Angular tiene la trampa de poner todo en el servicio de feature. Separar capas.

```typescript
// ❌ Viola SRP: un servicio hace HTTP, transforma datos, gestiona estado y formatea
@Injectable({ providedIn: "root" })
export class PaymentService {
  private readonly payments = signal<Payment[]>([]);

  // Responsabilidad 1: HTTP
  async loadPayments() {
    const raw = await firstValueFrom(
      this.http.get<ApiPayment[]>("/api/payments"),
    );
    // Responsabilidad 2: transformación/mapping
    const mapped = raw.map((p) => ({
      ...p,
      formattedAmount: `$${p.amount.toFixed(2)}`,
      formattedDate: new Date(p.date).toLocaleDateString(),
    }));
    // Responsabilidad 3: estado
    this.payments.set(mapped);
  }

  // Responsabilidad 4: lógica de negocio mezclada
  getActivePayments() {
    return this.payments().filter((p) => p.status === "active" && !p.archived);
  }

  // Responsabilidad 5: formateo
  formatPaymentSummary(p: Payment) {
    return `${p.recipient} — ${p.formattedAmount}`;
  }
}

// ✅ Cada clase tiene una sola razón para cambiar

// Capa 1: HTTP puro — solo habla con la API, solo retorna datos crudos
@Injectable({ providedIn: "root" })
export class PaymentsApiService {
  private readonly http = inject(HttpClient);

  getList(): Observable<ApiPayment[]> {
    return this.http.get<ApiPayment[]>("/api/payments");
  }

  create(payload: CreatePaymentDto): Observable<ApiPayment> {
    return this.http.post<ApiPayment>("/api/payments", payload);
  }
}

// Capa 2: Mappers puros (funciones, no clases) — fáciles de testear
const toPayment = (raw: ApiPayment): Payment => ({
  id: raw.id,
  recipient: raw.recipient_name,
  amount: raw.amount_cents / 100,
  status: raw.payment_status as PaymentStatus,
  date: new Date(raw.created_at),
});

// Capa 3: Estado — solo gestiona signals, delega HTTP a la API service
@Injectable({ providedIn: "root" })
export class PaymentsStateService {
  private readonly api = inject(PaymentsApiService);
  private readonly _payments = signal<Payment[]>([]);

  readonly payments = this._payments.asReadonly();
  readonly activePayments = computed(() =>
    this._payments().filter((p) => p.status === "active"),
  );

  async load(): Promise<void> {
    const raw = await firstValueFrom(this.api.getList());
    this._payments.set(raw.map(toPayment));
  }
}

// Capa 4: Pipes para formateo en templates — reutilizables, testeables
@Pipe({ name: "paymentSummary", standalone: true, pure: true })
export class PaymentSummaryPipe implements PipeTransform {
  transform(payment: Payment): string {
    return `${payment.recipient} — ${formatCurrency(payment.amount)}`;
  }
}
```

### O — Open/Closed con Directivas

Extender comportamiento sin modificar el componente base.

```typescript
// ❌ Agregar comportamientos al componente base — viola OCP
@Component({ selector: 'app-button', ... })
export class ButtonComponent {
  @Input() loading = false;
  @Input() tooltip = '';
  @Input() confirm = false; // cada nueva feature = modificar la clase

  handleClick() {
    if (this.confirm && !confirm('¿Estás seguro?')) return;
    this.clicked.emit();
  }
}

// ✅ Directivas que extienden sin modificar el componente base
// ButtonComponent nunca cambia — las directivas agregan comportamiento

@Directive({ selector: '[appLoadingState]', standalone: true })
export class LoadingStateDirective {
  @Input() appLoadingState = false;
  private readonly el = inject(ElementRef);

  @HostBinding('disabled') get isDisabled() { return this.appLoadingState; }
  @HostBinding('attr.aria-busy') get ariaBusy() { return this.appLoadingState; }
}

@Directive({ selector: '[appConfirmAction]', standalone: true })
export class ConfirmActionDirective {
  @Input() appConfirmAction = '¿Estás seguro?';
  @Output() confirmed = new EventEmitter<void>();

  @HostListener('click', ['$event'])
  onClick(e: Event) {
    e.stopPropagation();
    if (window.confirm(this.appConfirmAction)) {
      this.confirmed.emit();
    }
  }
}

// Uso: composición de comportamientos sin tocar ButtonComponent
// <app-button
//   [appLoadingState]="isSubmitting"
//   appConfirmAction="¿Confirmar pago?"
//   (confirmed)="submitPayment()"
// >
```

### D — Dependency Inversion con tokens de inyección

```typescript
// ❌ Acoplado a implementación concreta — difícil de testear y sustituir
@Injectable({ providedIn: "root" })
export class NotificationService {
  // acoplado directamente a una librería de toasts concreta
  show(message: string) {
    ToastLibrary.show({ message, duration: 3000 });
  }
}

// ✅ Interfaz + InjectionToken — la implementación es intercambiable
export interface Notifier {
  success(message: string): void;
  error(message: string): void;
  info(message: string): void;
}

export const NOTIFIER = new InjectionToken<Notifier>("NOTIFIER");

// Implementación concreta (puede ser reemplazada en tests o por entorno)
@Injectable()
export class ToastNotifier implements Notifier {
  success(message: string) {
    ToastLibrary.show({ message, type: "success" });
  }
  error(message: string) {
    ToastLibrary.show({ message, type: "error" });
  }
  info(message: string) {
    ToastLibrary.show({ message, type: "info" });
  }
}

// Registrar en providers
export const appConfig: ApplicationConfig = {
  providers: [{ provide: NOTIFIER, useClass: ToastNotifier }],
};

// Consumo: depende de la abstracción, no de la implementación
@Injectable({ providedIn: "root" })
export class PaymentService {
  private readonly notifier = inject(NOTIFIER); // ← interfaz, no clase concreta

  async submit(payment: Payment) {
    try {
      await firstValueFrom(this.api.create(payment));
      this.notifier.success("Pago enviado correctamente");
    } catch {
      this.notifier.error("Error al procesar el pago");
    }
  }
}

// En tests: implementación mock sin tocar la producción
TestBed.configureTestingModule({
  providers: [
    {
      provide: NOTIFIER,
      useValue: { success: jest.fn(), error: jest.fn(), info: jest.fn() },
    },
  ],
});
```

---

## DRY en Angular

### Interceptors en lugar de lógica repetida en servicios

```typescript
// ❌ El mismo manejo de auth y error copiado en cada servicio
@Injectable({ providedIn: "root" })
export class PaymentsService {
  getList() {
    const token = localStorage.getItem("token"); // duplicado
    return this.http
      .get("/api/payments", {
        headers: { Authorization: `Bearer ${token}` },
      })
      .pipe(
        catchError((err) => {
          // duplicado
          if (err.status === 401) this.router.navigate(["/login"]);
          return throwError(() => err);
        }),
      );
  }
}
// mismo código en TransactionsService, UsersService, etc.

// ✅ Un interceptor para cada concern — cero duplicación en servicios
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(AuthService).getToken();
  if (!token) return next(req);
  return next(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }));
};

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  return next(req).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401) router.navigate(["/login"]);
      if (err.status === 403) router.navigate(["/forbidden"]);
      return throwError(() => mapToApiError(err));
    }),
  );
};

// Registrar una vez — aplica a todos los servicios
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptors([authInterceptor, errorInterceptor])),
  ],
};
```

### Pipes puros para formateo reutilizable

```typescript
// ❌ La misma función de formateo en 6 componentes
// payments.component.ts
formatAmount(amount: number) { return `$${amount.toFixed(2)}`; }
// transactions.component.ts
formatAmount(amount: number) { return `$${amount.toFixed(2)}`; } // copiado

// ✅ Pipe puro — una implementación, reutilizable en cualquier template
@Pipe({ name: 'currency2', standalone: true, pure: true })
export class Currency2Pipe implements PipeTransform {
  transform(amount: number, currency = 'USD', locale = 'en-US'): string {
    return new Intl.NumberFormat(locale, { style: 'currency', currency }).format(amount);
  }
}

// Uso en cualquier template sin duplicar lógica:
// {{ payment.amount | currency2 }}
// {{ transaction.total | currency2: 'EUR' : 'de-DE' }}
```

---

## KISS en Angular

### Resolver simple en lugar de lógica de carga en ngOnInit

```typescript
// ❌ Loading state manual en cada componente de detalle
@Component({ ... })
export class PaymentDetailComponent implements OnInit {
  payment: Payment | null = null;
  isLoading = true;
  error: string | null = null;

  ngOnInit() {
    const id = this.route.snapshot.params['id'];
    this.api.getById(id).subscribe({
      next: p => { this.payment = p; this.isLoading = false; },
      error: e => { this.error = e.message; this.isLoading = false; },
    });
  }
}

// ✅ Resolver: el componente recibe datos ya cargados, sin boilerplate
export const paymentResolver: ResolveFn<Payment> = (route) => {
  return inject(PaymentsApiService).getById(route.params['id']);
};

// En las rutas:
{
  path: 'payments/:id',
  component: PaymentDetailComponent,
  resolve: { payment: paymentResolver },
}

// Componente: cero loading state, cero ngOnInit de fetching
@Component({ ... })
export class PaymentDetailComponent {
  protected readonly payment = inject(ActivatedRoute).snapshot.data['payment'] as Payment;
}
```

### Guard clauses en lugar de anidamiento

```typescript
// ❌ Anidamiento profundo — difícil de seguir el flujo
canActivate(route: ActivatedRouteSnapshot): boolean {
  if (this.auth.isLoggedIn()) {
    if (this.auth.hasRole('admin')) {
      if (!this.auth.isExpired()) {
        return true;
      } else {
        this.router.navigate(['/session-expired']);
        return false;
      }
    } else {
      this.router.navigate(['/forbidden']);
      return false;
    }
  } else {
    this.router.navigate(['/login']);
    return false;
  }
}

// ✅ Guard clauses — lectura lineal, cada caso manejado en su línea
canActivate(): boolean {
  if (!this.auth.isLoggedIn())    return this.redirect('/login');
  if (this.auth.isExpired())      return this.redirect('/session-expired');
  if (!this.auth.hasRole('admin')) return this.redirect('/forbidden');
  return true;
}

private redirect(path: string): false {
  this.router.navigate([path]);
  return false;
}
```

### Functional guards en lugar de clases

```typescript
// ❌ Clase completa para un guard simple
@Injectable({ providedIn: "root" })
export class AuthGuard implements CanActivate {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  canActivate(): boolean {
    if (this.auth.isLoggedIn()) return true;
    this.router.navigate(["/login"]);
    return false;
  }
}

// ✅ Functional guard — una función, cero boilerplate de clase
export const authGuard: CanActivateFn = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isLoggedIn() || router.createUrlTree(["/login"]);
};
```

---

## Checklist

```
SOLID:
  [ ] Servicios separados por capa: API (HTTP) / State / Business logic
  [ ] Mappers son funciones puras, no métodos de servicio
  [ ] Pipes para formateo, no métodos de componente
  [ ] Comportamiento extra en directivas, no en el componente base
  [ ] InjectionToken para implementaciones intercambiables

DRY:
  [ ] Auth, error handling y logging en interceptors — no en servicios
  [ ] Formateo reutilizable en pipes standalone puros
  [ ] Loading de datos en resolvers — no duplicado en cada componente
  [ ] Guards son funciones reutilizables (CanActivateFn)

KISS:
  [ ] Guard clauses en lugar de if anidados
  [ ] Functional guards en lugar de clases para lógica simple
  [ ] Resolvers para datos de ruta en lugar de ngOnInit con loading state
  [ ] Ninguna abstracción creada sin un segundo caso de uso que la justifique
```

## Version History

- v1.0.0 — Initial: SOLID con DI tokens, DRY con interceptors y pipes, KISS con resolvers
