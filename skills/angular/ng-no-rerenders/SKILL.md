---
name: ng-no-rerenders
description: Detects and eliminates unnecessary Angular change detection cycles: Default vs OnPush strategy, zone.js over-triggering, signals vs BehaviorSubject re-render cost, trackBy absence in lists, async pipe misuse, and heavy template expressions. Trigger: When user reports Angular performance issues, ExpressionChangedAfterItHasBeenChecked errors, or components re-rendering more than expected.
license: Apache-2.0
metadata:
  author: deuna
  version: "1.0"
  scope: [angular]
  auto_invoke: "Fixing Angular change detection or rendering performance"
allowed-tools: Read, Write, Bash, Glob
---

# Angular No Re-renders

> Change Detection en Angular no es magia — tiene reglas precisas.
> Entender cuándo y por qué dispara es la única forma de controlarlo.

## When to Use

- Componente re-renderiza más veces de lo esperado (confirmado con Angular DevTools)
- `ExpressionChangedAfterItHasBeenCheckedError` en consola
- Lista con `@for` o `*ngFor` que destruye y recrea todos los DOM nodes al actualizar
- Animaciones o interacciones lentas en componentes con mucho binding
- Migración de `ChangeDetectionStrategy.Default` a `OnPush`

---

## Mental Model: Cómo Funciona Change Detection en Angular

```
Default CD:
  Cualquier evento async → Zone.js lo intercepta → Angular verifica TODO el árbol
  Eventos interceptados: click, setTimeout, Promise, XHR, addEventListener...
  Resultado: incluso cambios en un componente hoja verifican el árbol completo

OnPush CD:
  Solo re-verifica el componente cuando:
    1. Un @Input() recibe una nueva referencia (no mutación)
    2. Un evento originado DENTRO del componente dispara
    3. Un Observable/Signal al que el template está suscrito emite
    4. Se llama markForCheck() o detectChanges() explícitamente
```

**Consecuencia:** Con `Default`, mutar un array (`array.push()`) actualiza la vista.  
Con `OnPush`, necesitas nueva referencia: `[...array, item]`.

---

## Causa 1 — ChangeDetectionStrategy.Default

El problema más impactante. Con Default, toda la app se verifica en cada evento.

```typescript
// ❌ Default: Angular verifica este componente en CADA evento de la app
@Component({
  selector: "app-payment-card",
  template: `<div>{{ payment.amount }}</div>`,
  changeDetection: ChangeDetectionStrategy.Default, // o simplemente omitido
})
export class PaymentCardComponent {
  @Input() payment!: Payment;
}

// ✅ OnPush: solo se verifica cuando payment referencia cambia o evento interno dispara
@Component({
  selector: "app-payment-card",
  standalone: true,
  template: `<div>{{ payment.amount }}</div>`,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PaymentCardComponent {
  @Input() payment!: Payment;
}
```

**Trampa OnPush con mutación:**

```typescript
// ❌ Mutación: OnPush no detecta el cambio (misma referencia)
this.payments.push(newPayment); // el array es el mismo objeto → OnPush no actualiza

// ✅ Nueva referencia: OnPush sí detecta
this.payments = [...this.payments, newPayment];
```

---

## Causa 2 — Template expressions con lógica pesada

Angular ejecuta las expresiones del template en CADA ciclo de CD.

```html
<!-- ❌ getFilteredPayments() se llama en cada CD cycle — puede ser costoso -->
@for (payment of getFilteredPayments(); track payment.id) {
<app-payment-card [payment]="payment" />
}

<!-- ❌ Mismo problema con pipes impuros o cálculos en template -->
<div>{{ payments.filter(p => p.status === 'active').length }} active</div>
```

```typescript
// ✅ Precalcular con signal o computed — solo recalcula cuando cambia la dep
export class PaymentListComponent {
  private readonly _payments = signal<Payment[]>([]);

  // computed: solo recalcula cuando _payments cambia
  protected readonly activePayments = computed(() =>
    this._payments().filter((p) => p.status === "active"),
  );

  protected readonly activeCount = computed(() => this.activePayments().length);
}
```

```html
<!-- ✅ Template consume el signal — se actualiza solo cuando computed cambia -->
@for (payment of activePayments(); track payment.id) {
<app-payment-card [payment]="payment" />
}
<div>{{ activeCount() }} active</div>
```

---

## Causa 3 — Ausencia de trackBy en listas

Sin `track`, Angular destruye y recrea todos los DOM nodes al actualizar el array.

```html
<!-- ❌ Sin track: toda la lista se recrea si cambia cualquier elemento -->
@for (item of items) {
<app-item [data]="item" />
}

<!-- ❌ track $index: mejor que nada, pero rota animaciones y estado interno -->
@for (item of items; track $index) {
<app-item [data]="item" />
}

<!-- ✅ track item.id: Angular reutiliza DOM nodes existentes, solo actualiza los que cambian -->
@for (item of items; track item.id) {
<app-item [data]="item" />
}

<!-- ✅ Para objetos sin id único, trackBy function -->
@for (item of items; track trackByFn(item)) {
<app-item [data]="item" />
}
```

```typescript
// trackBy debe ser una función pura — mismo input, mismo output
protected trackByFn(item: Payment): string {
  return `${item.type}-${item.id}`;
}
```

---

## Causa 4 — BehaviorSubject fuerza CD en cada emisión

Cada `.next()` en un BehaviorSubject que el template consume via `async` pipe
dispara un ciclo de CD, incluso si el valor es idéntico.

```typescript
// ❌ BehaviorSubject: emite aunque el valor no cambie → CD en cada next()
export class PaymentListComponent {
  readonly payments$ = new BehaviorSubject<Payment[]>([]);

  loadPayments() {
    this.api.getList().subscribe((data) => {
      this.payments$.next(data); // CD cycle aunque data sea idéntico
    });
  }
}
```

```typescript
// ✅ Signal: Angular compara referencias antes de disparar CD
export class PaymentListComponent {
  protected readonly payments = signal<Payment[]>([]);
  protected readonly isLoading = signal(false);

  // computed: no emite si el resultado no cambia
  protected readonly pendingCount = computed(
    () => this.payments().filter((p) => p.status === "pending").length,
  );

  loadPayments() {
    this.isLoading.set(true);
    this.api.getList().subscribe({
      next: (data) => this.payments.set(data), // CD solo si referencia cambia
      complete: () => this.isLoading.set(false),
    });
  }
}
```

```html
<!-- Signal en template: no necesita async pipe -->
@if (isLoading()) {
<app-loader />
} @else { @for (p of payments(); track p.id) {
<app-payment-card [payment]="p" />
}
<span>{{ pendingCount() }} pending</span>
}
```

---

## Causa 5 — Eventos de alta frecuencia dentro de Zone.js

Zone.js intercepta `mousemove`, `scroll`, `resize` → CD en cada evento → jank.

```typescript
// ❌ scroll y mousemove dentro de zone → CD en cada píxel de scroll
@Component({ ... })
export class ScrollableComponent implements AfterViewInit {
  ngAfterViewInit() {
    // Zone.js intercepta este listener → CD en cada scroll event
    window.addEventListener('scroll', this.onScroll.bind(this));
  }

  onScroll(e: Event) {
    // actualiza posición en pantalla — no necesita CD Angular
    this.updateParallax((e.target as Element).scrollTop);
  }
}

// ✅ Sacar el listener fuera de zone — CD no se dispara por scroll
@Component({ ... })
export class ScrollableComponent implements AfterViewInit {
  private readonly ngZone = inject(NgZone);
  private readonly elementRef = inject(ElementRef);

  ngAfterViewInit() {
    this.ngZone.runOutsideAngular(() => {
      // Zone.js no intercepta esto → CD nunca se dispara por scroll
      this.elementRef.nativeElement.addEventListener('scroll', (e: Event) => {
        this.updateParallax((e.target as Element).scrollTop);
        // Si en algún momento necesitas actualizar estado Angular:
        // this.ngZone.run(() => this.someSignal.set(value));
      });
    });
  }
}
```

---

## Causa 6 — Suscripciones manuales sin cleanup → memory leaks + CDs fantasma

Un componente destruido que sigue activo sigue disparando CD.

```typescript
// ❌ Suscripción sin cleanup — el componente sigue vivo tras destroy
export class PaymentComponent implements OnInit {
  ngOnInit() {
    this.service.payments$.subscribe((payments) => {
      this.payments = payments; // sigue ejecutándose aunque el componente esté destruido
    });
  }
}

// ✅ takeUntilDestroyed — cleanup automático al destruir el componente
export class PaymentComponent {
  private readonly destroyRef = inject(DestroyRef);

  ngOnInit() {
    this.service.payments$
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe((payments) => {
        this.payments.set(payments);
      });
  }
}
```

---

## Causa 7 — @Input mutable sin nueva referencia

Con OnPush, pasar el mismo objeto mutado no dispara CD.

```typescript
// Padre
// ❌ Mutación del objeto — OnPush en el hijo no ve el cambio
updatePayment() {
  this.selectedPayment.amount = 500; // misma referencia → OnPush hijo no actualiza
}

// ✅ Nueva referencia — OnPush sí detecta
updatePayment() {
  this.selectedPayment = { ...this.selectedPayment, amount: 500 };
}

// ✅ O usar signal en el hijo — se actualiza independientemente de OnPush
```

---

## Diagnóstico con Angular DevTools

```
1. Abrir Angular DevTools → Profiler
2. Click "Record"
3. Interactuar con la parte lenta de la app
4. Stop recording
5. Buscar componentes con:
   - Muchas barras de CD cycle
   - CD cycles de componentes que no deberían actualizarse
6. Click en el componente → ver "Change Detection" y "Source"
```

**Señales de problema:**

- Componente hoja disparando CD cuando su padre no cambió ningún Input
- Lista disparando CD en todos sus items cuando solo cambió uno
- Componentes de layout (header, sidebar) re-verificándose en cada interacción

---

## Checklist

```
Estrategia de CD:
  [ ] Todos los componentes usan ChangeDetectionStrategy.OnPush
  [ ] Arrays/objetos pasados como @Input son nuevas referencias al actualizar
  [ ] No hay mutaciones directas de @Input en el componente padre

Template:
  [ ] No hay llamadas a métodos en bindings de template ({{ getX() }}, [prop]="calc()")
  [ ] Cálculos costosos están en computed() o como propiedades precalculadas
  [ ] Todo @for tiene track item.id (nunca track $index en listas dinámicas)

Señales y observables:
  [ ] Estado local usa signal() en lugar de BehaviorSubject
  [ ] Toda suscripción tiene takeUntilDestroyed(this.destroyRef)
  [ ] No hay suscripciones manuales en templates (usar async pipe o signals)

Zone.js:
  [ ] Listeners de scroll/mousemove/resize corren en ngZone.runOutsideAngular()
  [ ] Solo se llama ngZone.run() cuando realmente se necesita actualizar la UI
```

## Version History

- v1.0.0 — Initial: Default vs OnPush, signals, trackBy, zone.js, memory leaks
