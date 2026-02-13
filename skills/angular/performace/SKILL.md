---
name: angular-performance
description: Angular performance optimization techniques including bundle size reduction, runtime optimization, and lazy loading strategies.
license: MIT
metadata:
  author: Community
  tags: angular, performance, optimization, bundle-size, lazy-loading
---

# Angular Performance Optimization

## Overview

Comprehensive performance optimization guide for Angular applications, covering build-time and runtime optimizations, bundle analysis, and lazy loading strategies.

## When to Apply

Use when:
- App has slow initial load time
- Bundle size is too large
- Runtime performance is poor
- Optimizing for Core Web Vitals

## Quick Reference

### 1. Enable Production Mode

**Impact**: CRITICAL

```typescript
// main.ts
import { enableProdMode } from '@angular/core';
import { environment } from './environments/environment';

if (environment.production) {
  enableProdMode();
}
```

### 2. Analyze Bundle Size

**Impact**: CRITICAL - Know what you're optimizing

```bash
# Build with stats
ng build --stats-json

# Analyze with webpack-bundle-analyzer
npx webpack-bundle-analyzer dist/your-app/stats.json

# Or use source-map-explorer
npm install -g source-map-explorer
source-map-explorer dist/your-app/*.js
```

### 3. Enable Build Optimizations

**Impact**: CRITICAL

```json
// angular.json
{
  "projects": {
    "your-app": {
      "architect": {
        "build": {
          "configurations": {
            "production": {
              "optimization": true,
              "buildOptimizer": true,
              "aot": true,
              "sourceMap": false,
              "namedChunks": false,
              "extractLicenses": true,
              "vendorChunk": false
            }
          }
        }
      }
    }
  }
}
```

### 4. Preload Lazy Modules

**Impact**: HIGH

```typescript
// app.config.ts
import { PreloadAllModules, provideRouter, withPreloading } from '@angular/router';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(
      routes, 
      withPreloading(PreloadAllModules)
    )
  ]
};

// Custom preloading strategy
export class CustomPreloadStrategy implements PreloadingStrategy {
  preload(route: Route, load: () => Observable<any>): Observable<any> {
    return route.data?.['preload'] ? load() : of(null);
  }
}

// Usage in routes
const routes: Routes = [
  {
    path: 'important',
    loadChildren: () => import('./important/routes'),
    data: { preload: true }
  },
  {
    path: 'less-important',
    loadChildren: () => import('./less-important/routes')
  }
];
```

### 5. Tree-shakable Providers

**Impact**: HIGH

```typescript
// ❌ Bad: Not tree-shakable
@NgModule({
  providers: [UserService]
})
export class AppModule {}

// ✅ Good: Tree-shakable
@Injectable({
  providedIn: 'root'
})
export class UserService {}
```

## Runtime Optimization

### 1. Pure Pipes

**Impact**: HIGH

```typescript
// ❌ Impure pipe - runs on every change detection
@Pipe({
  name: 'filter'
})
export class FilterPipe implements PipeTransform {
  transform(items: any[], searchText: string): any[] {
    return items.filter(item => 
      item.name.includes(searchText)
    );
  }
}

// ✅ Pure pipe - only runs when input changes
@Pipe({
  name: 'filter',
  pure: true
})
export class FilterPipe implements PipeTransform {
  transform(items: any[], searchText: string): any[] {
    return items.filter(item => 
      item.name.includes(searchText)
    );
  }
}
```

### 2. Detach Change Detection

**Impact**: MEDIUM - For components that rarely update

```typescript
@Component({
  selector: 'app-static-content',
  template: `<div>{{ content }}</div>`
})
export class StaticContentComponent implements OnInit {
  content = 'Static content';
  
  constructor(private cdr: ChangeDetectorRef) {}
  
  ngOnInit() {
    // Detach from change detection
    this.cdr.detach();
    
    // Manually trigger when needed
    setTimeout(() => {
      this.content = 'Updated';
      this.cdr.detectChanges();
    }, 5000);
  }
}
```

### 3. Zone-less Angular (Advanced)

**Impact**: HIGH - Eliminates Zone.js overhead

```typescript
// main.ts
import { enableProdMode } from '@angular/core';
import { bootstrapApplication } from '@angular/platform-browser';
import { provideExperimentalZonelessChangeDetection } from '@angular/core';

bootstrapApplication(AppComponent, {
  providers: [
    provideExperimentalZonelessChangeDetection()
  ]
});

// Components must use signals or manual change detection
@Component({
  selector: 'app-root',
  template: `<p>Count: {{ count() }}</p>`
})
export class AppComponent {
  count = signal(0);
  
  increment() {
    this.count.update(c => c + 1);
  }
}
```

## Bundle Size Optimization

### 1. Differential Loading

Automatically enabled in Angular - serves modern ES2017+ to modern browsers.

```json
// tsconfig.json
{
  "compilerOptions": {
    "target": "ES2022"
  }
}
```

### 2. Remove Unused Code

```bash
# Find unused exports
npx ts-prune

# Find unused dependencies
npx depcheck
```

### 3. Import Only What You Need

```typescript
// ❌ Bad: Imports entire library
import * as _ from 'lodash';
_.debounce(fn, 300);

// ✅ Good: Imports specific function
import { debounce } from 'lodash-es';
debounce(fn, 300);
```

### 4. Use CDN for Large Libraries

```html
<!-- index.html -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
```

```typescript
// Declare as external in angular.json
{
  "projects": {
    "your-app": {
      "architect": {
        "build": {
          "options": {
            "externalDependencies": ["chart.js"]
          }
        }
      }
    }
  }
}
```

## Image Optimization

### 1. NgOptimizedImage

**Impact**: HIGH

```typescript
import { NgOptimizedImage } from '@angular/common';

@Component({
  selector: 'app-image',
  standalone: true,
  imports: [NgOptimizedImage],
  template: `
    <img 
      ngSrc="hero.jpg" 
      width="400" 
      height="300"
      priority
    />
  `
})
export class ImageComponent {}
```

### 2. Lazy Load Images

```typescript
@Component({
  template: `
    <img 
      ngSrc="image.jpg" 
      width="400" 
      height="300"
      loading="lazy"
    />
  `
})
export class LazyImageComponent {}
```

## Network Optimization

### 1. HTTP Caching

```typescript
import { HttpClient, HttpHeaders } from '@angular/common/http';

@Injectable({ providedIn: 'root' })
export class CachedApiService {
  constructor(private http: HttpClient) {}
  
  getData() {
    const headers = new HttpHeaders({
      'Cache-Control': 'max-age=3600'
    });
    
    return this.http.get('/api/data', { headers });
  }
}
```

### 2. Service Worker (PWA)

```bash
ng add @angular/pwa
```

```typescript
// app.config.ts
import { provideServiceWorker } from '@angular/service-worker';

export const appConfig: ApplicationConfig = {
  providers: [
    provideServiceWorker('ngsw-worker.js', {
      enabled: environment.production,
      registrationStrategy: 'registerWhenStable:30000'
    })
  ]
};
```

## Monitoring Performance

### 1. Core Web Vitals

```bash
# Install Lighthouse
npm install -g lighthouse

# Run audit
lighthouse http://localhost:4200 --view
```

### 2. Angular DevTools

Install the Chrome extension for performance profiling.

### 3. Custom Performance Marks

```typescript
export class AppComponent implements OnInit {
  ngOnInit() {
    performance.mark('app-init-start');
    
    // App initialization...
    
    performance.mark('app-init-end');
    performance.measure('app-init', 'app-init-start', 'app-init-end');
    
    const measure = performance.getEntriesByName('app-init')[0];
    console.log('App init took', measure.duration, 'ms');
  }
}
```

## Common Pitfalls

### 1. Not Using OnPush Change Detection

Always use `ChangeDetectionStrategy.OnPush` for better performance.

### 2. Large Initial Bundles

Split code with lazy loading.

### 3. Not Analyzing Bundle

Run `ng build --stats-json` regularly.

### 4. Synchronous Operations in ngOnInit

```typescript
// ❌ Bad
ngOnInit() {
  this.data = this.processLargeDataset(); // Blocks UI
}

// ✅ Good
ngOnInit() {
  setTimeout(() => {
    this.data = this.processLargeDataset();
  }, 0);
}
```

## Checklist

- [ ] Enable production mode
- [ ] Use OnPush change detection
- [ ] Implement lazy loading
- [ ] Analyze bundle size
- [ ] Use pure pipes
- [ ] Optimize images with NgOptimizedImage
- [ ] Enable build optimizations
- [ ] Use trackBy with ngFor
- [ ] Implement virtual scrolling for large lists
- [ ] Remove unused dependencies
- [ ] Add service worker (PWA)
- [ ] Monitor Core Web Vitals

## References

- [Angular Performance Guide](https://angular.dev/best-practices/performance)
- [Web.dev Angular](https://web.dev/angular)
- [Bundle Buddy](https://github.com/samccone/bundle-buddy)

## Attribution

Community-curated best practices from Angular performance experts.
