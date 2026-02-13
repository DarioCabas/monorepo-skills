---
name: react-native-component-patterns
description: React Native component composition patterns, compound components, and reusable architecture best practices. Use when building scalable component libraries or refactoring complex components.
license: MIT
metadata:
  author: Community
  tags: react-native, components, patterns, composition, architecture
---

# React Native Component Patterns

## Overview

Best practices for building scalable, reusable, and maintainable React Native components using composition patterns, compound components, and clean architecture principles.

## When to Apply

Use these patterns when:
- Building reusable component libraries
- Refactoring components with too many props
- Designing flexible and extensible APIs
- Implementing complex UI components
- Creating design system components

## Quick Reference

### Compound Components Pattern

**❌ Avoid: Boolean prop proliferation**
```tsx
<Card 
  showHeader 
  showFooter 
  showAvatar 
  headerAlign="center"
  footerAlign="right"
/>
```

**✅ Prefer: Compound components**
```tsx
<Card>
  <Card.Header align="center">
    <Card.Avatar source={avatar} />
    <Card.Title>Title</Card.Title>
  </Card.Header>
  <Card.Body>Content</Card.Body>
  <Card.Footer align="right">
    <Card.Actions />
  </Card.Footer>
</Card>
```

### Container/Presenter Pattern

**❌ Avoid: Mixed concerns**
```tsx
function UserProfile() {
  const [user, setUser] = useState(null);
  
  useEffect(() => {
    fetchUser().then(setUser);
  }, []);
  
  return (
    <View style={styles.container}>
      <Image source={{ uri: user?.avatar }} />
      <Text style={styles.name}>{user?.name}</Text>
    </View>
  );
}
```

**✅ Prefer: Separated concerns**
```tsx
// Container (logic)
function UserProfileContainer() {
  const { data: user, isLoading } = useQuery(['user'], fetchUser);
  
  if (isLoading) return <Skeleton />;
  return <UserProfileView user={user} />;
}

// Presenter (UI)
function UserProfileView({ user }: { user: User }) {
  return (
    <View style={styles.container}>
      <Image source={{ uri: user.avatar }} />
      <Text style={styles.name}>{user.name}</Text>
    </View>
  );
}
```

### Render Props Pattern

**Use when**: You need to share stateful logic between components

```tsx
function DataProvider({ 
  children 
}: { 
  children: (data: Data, refetch: () => void) => React.ReactNode 
}) {
  const [data, setData] = useState<Data | null>(null);
  
  const fetchData = useCallback(() => {
    api.getData().then(setData);
  }, []);
  
  useEffect(() => { fetchData(); }, [fetchData]);
  
  return <>{children(data, fetchData)}</>;
}

// Usage
<DataProvider>
  {(data, refetch) => (
    <View>
      <Text>{data?.title}</Text>
      <Button onPress={refetch} title="Refresh" />
    </View>
  )}
</DataProvider>
```

### Custom Hooks Pattern

**✅ Best for reusable logic**
```tsx
function useUser(userId: string) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    setLoading(true);
    fetchUser(userId)
      .then(setUser)
      .finally(() => setLoading(false));
  }, [userId]);
  
  return { user, loading };
}

// Usage
function UserProfile({ userId }: { userId: string }) {
  const { user, loading } = useUser(userId);
  
  if (loading) return <Skeleton />;
  return <UserView user={user} />;
}
```

## Component Architecture Best Practices

### 1. Single Responsibility Principle

Each component should do one thing well:

```tsx
// ❌ Bad: Component does too much
function UserDashboard() {
  // Handles auth, data fetching, navigation, and rendering
}

// ✅ Good: Split responsibilities
function UserDashboard() {
  return (
    <AuthGuard>
      <UserDataProvider>
        <DashboardLayout>
          <DashboardContent />
        </DashboardLayout>
      </UserDataProvider>
    </AuthGuard>
  );
}
```

### 2. Prop Drilling vs Context

**❌ Avoid: Deep prop drilling**
```tsx
<App>
  <Layout theme={theme}>
    <Header theme={theme}>
      <Nav theme={theme}>
        <NavItem theme={theme} />
      </Nav>
    </Header>
  </Layout>
</App>
```

**✅ Use: Context for shared state**
```tsx
const ThemeContext = createContext<Theme>(defaultTheme);

function App() {
  return (
    <ThemeContext.Provider value={theme}>
      <Layout>
        <Header>
          <Nav>
            <NavItem />
          </Nav>
        </Header>
      </Layout>
    </ThemeContext.Provider>
  );
}

function NavItem() {
  const theme = useContext(ThemeContext);
  return <Text style={{ color: theme.primary }}>Item</Text>;
}
```

### 3. Component Composition over Configuration

**❌ Avoid: Over-configuration**
```tsx
<List
  renderHeader={() => <Header />}
  renderItem={(item) => <Item data={item} />}
  renderFooter={() => <Footer />}
  renderEmpty={() => <Empty />}
  renderLoading={() => <Loading />}
/>
```

**✅ Prefer: Composition**
```tsx
<List data={items}>
  <List.Header>
    <Header />
  </List.Header>
  <List.Items>
    {(item) => <Item data={item} />}
  </List.Items>
  <List.Footer>
    <Footer />
  </List.Footer>
</List>
```

### 4. Forward Refs for Reusable Components

```tsx
const Input = forwardRef<TextInput, InputProps>((props, ref) => {
  return (
    <TextInput
      ref={ref}
      {...props}
      style={[styles.input, props.style]}
    />
  );
});

// Usage: Parent can access TextInput methods
function Form() {
  const inputRef = useRef<TextInput>(null);
  
  const focusInput = () => {
    inputRef.current?.focus();
  };
  
  return <Input ref={inputRef} />;
}
```

## Common Pitfalls

### 1. Over-abstracting Too Early

Don't create abstractions until you have at least 3 similar use cases.

### 2. Props Interface Explosion

If a component has more than 10 props, consider:
- Breaking it into smaller components
- Using composition instead
- Grouping related props into objects

### 3. Not Using TypeScript Generics

```tsx
// ❌ Bad: Type repetition
function List({ items }: { items: User[] }) {
  return items.map(item => <UserItem user={item} />);
}

// ✅ Good: Generic component
function List<T>({ 
  items, 
  renderItem 
}: { 
  items: T[]; 
  renderItem: (item: T) => React.ReactNode;
}) {
  return <>{items.map(renderItem)}</>;
}
```

## Performance Considerations

### 1. Memoization with React.memo

```tsx
const ExpensiveComponent = React.memo(({ data }: Props) => {
  // Heavy rendering logic
  return <View>...</View>;
}, (prevProps, nextProps) => {
  // Custom comparison
  return prevProps.data.id === nextProps.data.id;
});
```

### 2. useCallback for Event Handlers

```tsx
function Parent() {
  const [count, setCount] = useState(0);
  
  // ✅ Memoized callback
  const handlePress = useCallback(() => {
    setCount(c => c + 1);
  }, []);
  
  return <Child onPress={handlePress} />;
}
```

## References

For more React Native specific optimizations, see:
- [react-native-best-practices](../best-practices/SKILL.md)
- React Compiler for automatic memoization
- FlashList for performant lists

## Attribution

Community-curated best practices from React Native experts and the React documentation.
