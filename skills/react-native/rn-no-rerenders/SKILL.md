---
name: rn-no-rerenders
description: Detects and eliminates unnecessary re-renders in React Native: inline objects/arrays/functions in JSX, missing or broken memo, unstable useCallback/useMemo deps, FlatList row churn, derived state in useState, and context over-broadcasting. Trigger: When user reports re-render issues, flickering, FlatList jank, or wants to optimize component rendering performance.
license: Apache-2.0
metadata:
  author: deuna
  version: "1.0"
  scope: [react-native]
  auto_invoke: "Fixing re-renders or optimizing component performance"
allowed-tools: Read, Write, Bash, Glob
---

# RN No Re-renders

> Encuentra la causa raíz de cada re-render innecesario y la elimina.
> No adivines — diagnostica primero, luego aplica el fix correcto.

## When to Use

- Usuario reporta flickering, lag, o listas lentas en React Native
- Profiler / Flipper muestra renders repetidos en componentes que no deberían actualizarse
- `memo()` está aplicado pero el componente sigue re-renderizando
- FlatList re-renderiza todas las filas cuando cambia un item
- Un cambio de estado en un padre causa cascada de renders en hijos

## Mental Model: Por Qué Re-renderiza React Native

```
Un componente re-renderiza cuando:
  1. Su propio estado cambia (useState, useReducer)
  2. Un contexto del que depende cambia
  3. Su padre re-renderiza Y le pasa una nueva referencia como prop

JavaScript crea una NUEVA referencia para cada literal:
  {}          → nuevo objeto cada render
  []          → nuevo array cada render
  () => {}    → nueva función cada render

memo() hace shallow comparison de props.
Si UNA prop es nueva referencia → memo() falla → re-render igual.
```

**Consecuencia práctica:** `memo()` sin `useCallback`/`useMemo` en el padre es inútil.

---

## Diagnóstico Primero

Antes de aplicar cualquier fix, identificar la causa exacta:

```tsx
// Paso 1: agregar log temporal para contar renders
const MyComponent = memo(({ data, onPress }) => {
  console.count(`MyComponent render`); // ¿cuántas veces?
  // ...
});

// Paso 2: identificar qué prop cambió usando useRef
const prevProps = useRef({ data, onPress });
useEffect(() => {
  if (prevProps.current.data !== data) console.log("data changed ref");
  if (prevProps.current.onPress !== onPress)
    console.log("onPress changed ref — likely inline fn");
  prevProps.current = { data, onPress };
});
```

Con Flipper: **React DevTools → Profiler → "Record why each component rendered"**

---

## Causa 1 — Inline objects/arrays/functions en JSX

El más común. Ocurre cuando se pasan literales directamente como props.

```tsx
// ❌ Tres nuevas referencias en cada render del padre
<Card
  style={{ marginTop: 8 }}
  data={[item1, item2]}
  onPress={() => handlePress(id)}
/>;

// ✅ Referencias estables
const CARD_STYLE = { marginTop: 8 } as const; // fuera del componente

const Parent = () => {
  const data = useMemo(() => [item1, item2], [item1, item2]);
  const handleCardPress = useCallback(() => handlePress(id), [handlePress, id]);

  return <Card style={CARD_STYLE} data={data} onPress={handleCardPress} />;
};
```

**Regla:** Todo lo que no depende de props/state → fuera del componente como constante de módulo.

```tsx
// Constantes de módulo: nunca se recrean
const HIT_SLOP = { top: 8, bottom: 8, left: 0, right: 0 } as const;
const CONTENT_STYLE = { paddingBottom: 24 } as const;
const SEPARATOR_STYLE = { height: 1, backgroundColor: "#E5E7EB" } as const;
```

---

## Causa 2 — StyleSheet.create dentro del componente

```tsx
// ❌ StyleSheet.create() se ejecuta en cada render
const MyComponent = () => {
  const styles = StyleSheet.create({ container: { flex: 1 } }); // ← aquí
  return <View style={styles.container} />;
};

// ✅ Fuera del componente — se ejecuta una sola vez al importar el módulo
const styles = StyleSheet.create({
  container: { flex: 1 },
});
const MyComponent = () => <View style={styles.container} />;
```

---

## Causa 3 — memo() roto por función inline en el padre

```tsx
// ❌ memo en el hijo es completamente inútil
//    El padre recrea onPress en cada render → nueva referencia → memo falla
const Child = memo(({ onPress }: { onPress: () => void }) => {
  console.log("Child rendered"); // se ejecuta en cada render del padre
  return <Pressable onPress={onPress} />;
});

const Parent = () => {
  const [count, setCount] = useState(0);
  return (
    <>
      <Text>{count}</Text>
      <Child onPress={() => setCount((c) => c + 1)} />{" "}
      {/* ← nuevo fn cada render */}
    </>
  );
};

// ✅ useCallback estabiliza la referencia
const Parent = () => {
  const [count, setCount] = useState(0);
  const handlePress = useCallback(() => setCount((c) => c + 1), []); // sin deps → estable
  return (
    <>
      <Text>{count}</Text>
      <Child onPress={handlePress} /> {/* misma referencia → memo funciona */}
    </>
  );
};
```

---

## Causa 4 — Dependencias incorrectas o faltantes en useCallback/useMemo

```tsx
// ❌ Stale closure: id cambia pero handlePress sigue usando el id inicial
const handlePress = useCallback(() => {
  navigate(id); // id capturado en el cierre inicial
}, []); // bug: id no está en deps

// ❌ Over-memoization: memo se invalida en cada render de todos modos
const value = useMemo(() => ({ data }), [data, Math.random()]); // Math.random() siempre cambia

// ✅ Deps completas y estables
const handlePress = useCallback(() => {
  navigate(id);
}, [navigate, id]); // todas las variables del closure deben estar aquí

// ✅ Solo deps que realmente cambian el resultado
const value = useMemo(() => ({ data }), [data]);
```

**Herramienta:** `eslint-plugin-react-hooks` con `exhaustive-deps` en warning — nunca ignorar.

---

## Causa 5 — Estado derivado en useState

```tsx
// ❌ totalAmount debe sincronizarse manualmente con items → bug garantizado
const [items, setItems] = useState<CartItem[]>([]);
const [totalAmount, setTotalAmount] = useState(0);
// Si olvidas actualizar totalAmount después de setItems → inconsistencia

// ✅ Derivar en render — siempre en sincronía, una sola fuente de verdad
const [items, setItems] = useState<CartItem[]>([]);
const totalAmount = useMemo(
  () => items.reduce((sum, item) => sum + item.price * item.qty, 0),
  [items], // se recalcula solo cuando items cambia
);
```

---

## Causa 6 — Context re-renderiza todos los consumidores

```tsx
// ❌ Un solo contexto con valores de diferente frecuencia de cambio
//    Cada vez que cart cambia → user y theme consumers re-renderizan también
const AppContext = createContext({ user, theme, cart });

// ✅ Separar por frecuencia de cambio
const UserContext = createContext(user); // cambia: al login/logout
const ThemeContext = createContext(theme); // cambia: al toggle de tema
const CartContext = createContext(cart); // cambia: en cada operación del carrito

// Cada componente solo suscribe al contexto que necesita
const CartBadge = () => {
  const cart = useContext(CartContext); // no re-renderiza con cambios de user o theme
  return <Text>{cart.itemCount}</Text>;
};
```

---

## Causa 7 — useRef para valores que no deben disparar renders

```tsx
// ❌ ID del timer en estado → re-render cuando se setea el timer
const [timerId, setTimerId] = useState<ReturnType<typeof setTimeout> | null>(
  null,
);
const start = () => setTimerId(setTimeout(doSomething, 3000)); // causa render

// ✅ Ref: persiste entre renders, mutarlo no dispara render
const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
const start = useCallback(() => {
  timerRef.current = setTimeout(doSomething, 3000); // sin render
}, []);
const stop = useCallback(() => {
  if (timerRef.current) clearTimeout(timerRef.current);
}, []);

// Otros buenos candidatos para useRef:
// - Posición de scroll
// - ID de requestAnimationFrame
// - Valor anterior de una prop para comparar
// - Flag de "ya se montó por primera vez"
```

---

## Causa 8 — FlatList: row churn por keyExtractor y renderItem inestables

```tsx
// ❌ keyExtractor y renderItem son nuevas funciones en cada render
//    → FlatList no puede reusar celdas → destroza y recrea filas
const MyList = ({ items, onItemPress }) => (
  <FlatList
    data={items}
    keyExtractor={(item) => item.id} // nueva función cada render
    renderItem={(
      { item }, // nueva función cada render
    ) => <ItemRow item={item} onPress={onItemPress} />}
  />
);

// ✅ Estabilizar con useCallback
const MyList = memo(({ items, onItemPress }) => {
  const keyExtractor = useCallback((item: Item) => item.id, []);

  const renderItem = useCallback<ListRenderItem<Item>>(
    ({ item }) => <ItemRow item={item} onPress={onItemPress} />,
    [onItemPress],
  ); // onItemPress debe ser estable en el padre (useCallback)

  return (
    <FlatList
      data={items}
      keyExtractor={keyExtractor}
      renderItem={renderItem}
      // Para filas de altura fija: elimina medición asíncrona
      getItemLayout={(_data, index) => ({
        length: ITEM_HEIGHT,
        offset: ITEM_HEIGHT * index,
        index,
      })}
    />
  );
});

const ITEM_HEIGHT = 72; // medir en dispositivo real
```

---

## Causa 9 — useEffect como event handler (anti-patrón muy común)

```tsx
// ❌ useEffect reacciona a un flag de estado → render extra innecesario
const [shouldFetch, setShouldFetch] = useState(false);
useEffect(() => {
  if (shouldFetch) {
    fetchData();
    setShouldFetch(false); // otro render para resetear
  }
}, [shouldFetch]);
const handleRefresh = () => setShouldFetch(true); // render para setear flag

// ✅ Llamar directamente desde el handler — cero renders extra
const handleRefresh = useCallback(async () => {
  await fetchData();
}, [fetchData]);
```

---

## Checklist de Re-renders

Al revisar o escribir un componente, verificar en orden:

```
Fuentes de referencia inestable:
  [ ] StyleSheet.create está fuera del componente (nivel de módulo)
  [ ] No hay objetos literales {} en JSX como props
  [ ] No hay arrays literales [] en JSX como props
  [ ] No hay arrow functions () => {} en JSX como props a hijos memo'd
  [ ] Constantes que no dependen de props/state están fuera del componente

memo y callbacks:
  [ ] memo() aplicado en componentes que reciben props object/function
  [ ] useCallback en TODOS los handlers pasados como props
  [ ] useMemo para objetos/arrays pasados como props a hijos memo'd
  [ ] Deps de useCallback/useMemo son completas (sin omisiones)
  [ ] Deps de useCallback/useMemo no incluyen valores que siempre cambian

Estado:
  [ ] No hay estado derivado en useState (usar useMemo)
  [ ] Valores que no disparan render están en useRef (timers, flags, scroll pos)
  [ ] No hay useEffect usado como event handler

Context:
  [ ] Contextos están divididos por frecuencia de cambio
  [ ] Componentes solo suscriben al contexto que necesitan

FlatList:
  [ ] keyExtractor estable (useCallback o función de módulo)
  [ ] renderItem estable (useCallback)
  [ ] getItemLayout implementado para filas de altura fija
```

## Version History

- v1.0.0 — Initial: diagnóstico, 9 causas documentadas con fix, checklist
