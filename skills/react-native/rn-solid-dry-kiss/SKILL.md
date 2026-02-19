---
name: rn-solid-dry-kiss
description: Applies SOLID, DRY, and KISS principles to React Native TypeScript code: single responsibility components, open/closed hooks, dependency inversion via props/context, eliminating duplicated logic, and keeping implementations simple over clever. Trigger: When user asks to refactor, review, or write clean React Native code following software engineering principles.
license: Apache-2.0
metadata:
  author: deuna
  version: "1.0"
  scope: [react-native]
  auto_invoke: "Refactoring or reviewing React Native code for clean architecture"
allowed-tools: Read, Write, Bash, Glob
---

# RN SOLID · DRY · KISS

> Tres principios, una meta: código que cualquier miembro del equipo puede leer,
> modificar y extender sin miedo. Aplicados al contexto específico de React Native.

## When to Use

- Usuario pide refactorizar un componente o hook que "se fue creciendo"
- Componente tiene más de 200 líneas o hace demasiadas cosas
- Lógica duplicada entre componentes o pantallas similares
- Hook o utilidad que es difícil de testear por tener muchas responsabilidades
- Code review donde se detectan violaciones de estos principios

---

## SOLID en React Native

### S — Single Responsibility: un componente, una razón para cambiar

El síntoma más común: un componente que mezcla lógica de negocio, fetching de datos, formateo y UI en el mismo archivo.

```tsx
// ❌ Viola SRP: este componente hace fetching, lógica de negocio, formateo y UI
const PaymentScreen = () => {
  const [payments, setPayments] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    setIsLoading(true);
    fetch("/api/payments")
      .then((r) => r.json())
      .then((data) => {
        // lógica de negocio mezclada con fetching
        const filtered = data.filter((p) => p.status !== "cancelled");
        const sorted = filtered.sort((a, b) => b.date - a.date);
        setPayments(sorted);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const formatAmount = (amount: number) => `$${amount.toFixed(2)}`; // formateo mezclado con UI

  if (isLoading) return <ActivityIndicator />;

  return (
    <FlatList
      data={payments}
      renderItem={({ item }) => (
        <View>
          <Text>{item.recipient}</Text>
          <Text>{formatAmount(item.amount)}</Text>
        </View>
      )}
    />
  );
};

// ✅ Cada pieza tiene una sola responsabilidad
// 1. Hook: fetching + lógica de negocio
const usePayments = () => {
  const [payments, setPayments] = useState<Payment[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    setIsLoading(true);
    fetchPayments()
      .then(filterAndSort)
      .then(setPayments)
      .finally(() => setIsLoading(false));
  }, []);

  return { payments, isLoading };
};

// 2. Utilidad pura: formateo (testeable sin render)
const formatAmount = (amount: number, currency = "USD"): string =>
  new Intl.NumberFormat("en-US", { style: "currency", currency }).format(
    amount,
  );

// 3. Componente de fila: solo UI
const PaymentRow = memo(({ payment }: { payment: Payment }) => (
  <View style={styles.row}>
    <Text style={styles.recipient}>{payment.recipient}</Text>
    <Text style={styles.amount}>{formatAmount(payment.amount)}</Text>
  </View>
));

// 4. Pantalla: solo composición
const PaymentScreen = () => {
  const { payments, isLoading } = usePayments();
  if (isLoading) return <ActivityIndicator />;
  return (
    <FlatList
      data={payments}
      renderItem={({ item }) => <PaymentRow payment={item} />}
    />
  );
};
```

### O — Open/Closed: abierto para extensión, cerrado para modificación

Usar variantes/config en lugar de agregar condicionales al componente base.

```tsx
// ❌ Cada nuevo tipo de botón requiere modificar el componente base
const Button = ({ type, label, onPress }) => {
  if (type === "primary")
    return (
      <Pressable style={styles.primary}>
        <Text>{label}</Text>
      </Pressable>
    );
  if (type === "danger")
    return (
      <Pressable style={styles.danger}>
        <Text>{label}</Text>
      </Pressable>
    );
  if (type === "ghost")
    return (
      <Pressable style={styles.ghost}>
        <Text>{label}</Text>
      </Pressable>
    );
  // cada nueva variante = modificar este archivo
};

// ✅ El componente base no cambia; se extiende con configuración
const VARIANTS = {
  primary: { container: styles.primaryContainer, label: styles.primaryLabel },
  danger: { container: styles.dangerContainer, label: styles.dangerLabel },
  ghost: { container: styles.ghostContainer, label: styles.ghostLabel },
} as const satisfies Record<string, { container: ViewStyle; label: TextStyle }>;

type ButtonVariant = keyof typeof VARIANTS;

const Button = memo(
  ({
    variant = "primary",
    label,
    onPress,
  }: {
    variant?: ButtonVariant;
    label: string;
    onPress: () => void;
  }) => {
    const { container, label: labelStyle } = VARIANTS[variant];
    return (
      <Pressable style={container} onPress={onPress}>
        <Text style={labelStyle}>{label}</Text>
      </Pressable>
    );
  },
);

// Agregar una variante nueva = solo agregar una entrada al objeto VARIANTS
// El componente Button nunca se toca.
```

### D — Dependency Inversion: depender de abstracciones, no de implementaciones

```tsx
// ❌ El componente depende directamente de un servicio concreto
const TransactionList = () => {
  const [data, setData] = useState([]);
  useEffect(() => {
    // acoplado a la implementación concreta de fetching
    fetch("https://api.deuna.com/transactions")
      .then((r) => r.json())
      .then(setData);
  }, []);
  return <FlatList data={data} renderItem={renderItem} />;
};

// ✅ El componente depende de una abstracción (hook/prop)
// La implementación concreta se inyecta desde fuera

// Abstracción: el componente no sabe cómo se obtienen los datos
interface TransactionListProps {
  transactions: Transaction[];
  isLoading: boolean;
  onRefresh: () => void;
}

const TransactionList = memo(
  ({ transactions, isLoading, onRefresh }: TransactionListProps) => (
    <FlatList
      data={transactions}
      refreshing={isLoading}
      onRefresh={onRefresh}
      renderItem={renderItem}
    />
  ),
);

// Implementación concreta en el hook (fácil de sustituir en tests)
const useTransactions = () => {
  const [transactions, setTransactions] = useState<Transaction[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const load = useCallback(async () => {
    setIsLoading(true);
    try {
      setTransactions(await transactionsApi.getList());
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  return { transactions, isLoading, onRefresh: load };
};

// Pantalla: conecta la abstracción con la implementación
const TransactionsScreen = () => {
  const props = useTransactions();
  return <TransactionList {...props} />;
};
```

---

## DRY en React Native

### No repetir lógica — extraer a hooks y utilidades

```tsx
// ❌ La misma lógica de loading/error/retry copiada en 5 pantallas
const PaymentsScreen = () => {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  useEffect(() => {
    setLoading(true);
    paymentsApi
      .getList()
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);
  // ...
};

const TransactionsScreen = () => {
  // misma lógica copiada
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  // ...
};

// ✅ Un hook genérico para el patrón async → una sola implementación
type AsyncState<T> = { data: T | null; loading: boolean; error: Error | null };

const useAsync = <T,>(fn: () => Promise<T>, deps: DependencyList = []) => {
  const [state, setState] = useState<AsyncState<T>>({
    data: null,
    loading: false,
    error: null,
  });

  const execute = useCallback(async () => {
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      const data = await fn();
      setState({ data, loading: false, error: null });
    } catch (error) {
      setState((s) => ({ ...s, loading: false, error: error as Error }));
    }
  }, deps);

  useEffect(() => {
    execute();
  }, [execute]);

  return { ...state, retry: execute };
};

// Uso: cero boilerplate en cada pantalla
const PaymentsScreen = () => {
  const { data, loading, error, retry } = useAsync(
    () => paymentsApi.getList(),
    [],
  );
  // ...
};

const TransactionsScreen = () => {
  const { data, loading, error, retry } = useAsync(
    () => transactionsApi.getList(),
    [],
  );
  // ...
};
```

### No repetir estilos — tokens como única fuente de verdad

```tsx
// ❌ Mismo valor hardcodeado en múltiples archivos
// card.styles.ts
const styles = StyleSheet.create({ card: { borderRadius: 8, padding: 16 } });
// modal.styles.ts
const styles = StyleSheet.create({
  container: { borderRadius: 8, padding: 16 },
});
// input.styles.ts
const styles = StyleSheet.create({ wrapper: { borderRadius: 8, padding: 16 } });

// ✅ Un solo lugar — los tokens del DS
import { tokens } from "@deuna/tl-design-system-mobile-rn";

// card.styles.ts
const styles = StyleSheet.create({
  card: {
    borderRadius: tokens.border.radius.md,
    padding: tokens.spacing.md,
  },
});
// modal y input usan los mismos tokens — cambiar borderRadius.md = cambia en todos
```

---

## KISS en React Native

### Preferir lo simple sobre lo ingenioso

```tsx
// ❌ Sobre-ingeniería: factory pattern para algo que no lo necesita
const createButtonHandler =
  (config: ButtonConfig) =>
  (handlerFactory: HandlerFactory) =>
  (eventBus: EventBus) =>
  () =>
    handlerFactory.create(config).dispatch(eventBus);

// ✅ Una función directa
const handlePaymentPress = useCallback(() => {
  navigation.navigate("PaymentDetail", { id: payment.id });
}, [navigation, payment.id]);
```

```tsx
// ❌ Condicional anidado ilegible
const getStatusColor = (status: string, isExpired: boolean, isVip: boolean) => {
  if (status === "active") {
    if (isVip) {
      return isExpired ? "gold-expired" : "gold";
    } else {
      return isExpired ? "red" : "green";
    }
  } else {
    return isExpired ? "grey-expired" : "grey";
  }
};

// ✅ Lookup table — O(1), legible, extensible sin tocar lógica
const STATUS_COLOR: Record<string, string> = {
  "active-vip-expired": "gold-expired",
  "active-vip": "gold",
  "active-expired": "red",
  active: "green",
  "inactive-expired": "grey-expired",
  inactive: "grey",
};

const getStatusColor = (
  status: string,
  isExpired: boolean,
  isVip: boolean,
): string => {
  const key = [status, isVip && "vip", isExpired && "expired"]
    .filter(Boolean)
    .join("-");
  return STATUS_COLOR[key] ?? "grey";
};
```

```tsx
// ❌ Early return ausente — anidamiento profundo
const processPayment = async (payment: Payment) => {
  if (payment) {
    if (payment.status === "pending") {
      if (payment.amount > 0) {
        await submitPayment(payment);
      }
    }
  }
};

// ✅ Guard clauses / early return — lectura lineal
const processPayment = async (payment: Payment) => {
  if (!payment) return;
  if (payment.status !== "pending") return;
  if (payment.amount <= 0) return;

  await submitPayment(payment);
};
```

---

## Checklist

```
SOLID:
  [ ] Cada componente tiene una sola razón para cambiar
  [ ] Lógica de negocio y fetching en hooks, no en componentes
  [ ] Variantes configuradas con objetos/constantes, no con if/switch en el componente
  [ ] Componentes reciben datos por props, no los obtienen directamente

DRY:
  [ ] Ningún bloque de lógica está copiado en más de un lugar
  [ ] Patrones async (loading/error/retry) extraídos a un hook reutilizable
  [ ] Valores de estilo provienen de tokens, no de literales repetidos

KISS:
  [ ] Ninguna abstracción fue creada "por si acaso" (YAGNI)
  [ ] Condicionales complejos reemplazados por lookup tables
  [ ] Early returns usados para eliminar anidamiento
  [ ] La implementación más simple que resuelve el problema actual
```

## Version History

- v1.0.0 — Initial: SOLID con ejemplos RN, DRY con useAsync, KISS con guard clauses
