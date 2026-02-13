---
name: nestjs-best-practices
description: NestJS best practices covering architecture, dependency injection, error handling, validation, and security patterns.
license: MIT
metadata:
  author: Community
  tags: nestjs, nodejs, typescript, backend, api
---

# NestJS Best Practices

## Overview

Comprehensive guide for building scalable, maintainable NestJS applications using proper architecture, dependency injection, validation, and security best practices.

## When to Apply

Use these guidelines when:
- Building new NestJS applications
- Refactoring existing NestJS code
- Implementing authentication/authorization
- Designing API architecture
- Optimizing NestJS performance

## Quick Reference

### Module Organization

**Impact**: HIGH - Affects maintainability

**✅ Feature-based modules**
```
src/
├── app.module.ts
├── common/
│   ├── filters/
│   ├── guards/
│   ├── interceptors/
│   └── pipes/
├── config/
│   └── configuration.ts
├── users/
│   ├── users.module.ts
│   ├── users.controller.ts
│   ├── users.service.ts
│   ├── dto/
│   │   ├── create-user.dto.ts
│   │   └── update-user.dto.ts
│   └── entities/
│       └── user.entity.ts
└── auth/
    ├── auth.module.ts
    ├── auth.controller.ts
    ├── auth.service.ts
    └── strategies/
        └── jwt.strategy.ts
```

### Dependency Injection

**Impact**: CRITICAL

**❌ Bad: Direct instantiation**
```typescript
export class UsersService {
  private readonly repository = new UserRepository();
  
  async findAll() {
    return this.repository.find();
  }
}
```

**✅ Good: Constructor injection**
```typescript
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}
  
  async findAll(): Promise<User[]> {
    return this.userRepository.find();
  }
}
```

### DTOs with Validation

**Impact**: CRITICAL - Prevents invalid data

**✅ Always use DTOs with class-validator**
```typescript
import { IsString, IsEmail, MinLength, IsOptional } from 'class-validator';

export class CreateUserDto {
  @IsString()
  @MinLength(2)
  name: string;
  
  @IsEmail()
  email: string;
  
  @IsString()
  @MinLength(8)
  password: string;
  
  @IsOptional()
  @IsString()
  avatar?: string;
}

// In controller
@Post()
async create(@Body() createUserDto: CreateUserDto) {
  return this.usersService.create(createUserDto);
}

// Enable validation globally in main.ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
}));
```

### Exception Handling

**Impact**: HIGH

**✅ Use built-in HTTP exceptions**
```typescript
import { 
  Injectable, 
  NotFoundException,
  BadRequestException,
  UnauthorizedException 
} from '@nestjs/common';

@Injectable()
export class UsersService {
  async findOne(id: string): Promise<User> {
    const user = await this.userRepository.findOne({ where: { id } });
    
    if (!user) {
      throw new NotFoundException(`User with ID ${id} not found`);
    }
    
    return user;
  }
  
  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.userRepository.findOne({ 
      where: { email: dto.email } 
    });
    
    if (existing) {
      throw new BadRequestException('Email already exists');
    }
    
    return this.userRepository.save(dto);
  }
}
```

### Custom Exception Filters

**✅ Global error handling**
```typescript
import { 
  ExceptionFilter, 
  Catch, 
  ArgumentsHost, 
  HttpException 
} from '@nestjs/common';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();
    const status = exception.getStatus();
    
    response.status(status).json({
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message: exception.message,
    });
  }
}

// Register globally
app.useGlobalFilters(new HttpExceptionFilter());
```

## Authentication & Authorization

### JWT Strategy

**Impact**: CRITICAL

```typescript
// jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private usersService: UsersService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      secretOrKey: process.env.JWT_SECRET,
    });
  }
  
  async validate(payload: { sub: string; email: string }) {
    const user = await this.usersService.findOne(payload.sub);
    
    if (!user) {
      throw new UnauthorizedException();
    }
    
    return user;
  }
}

// auth.module.ts
@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET,
      signOptions: { expiresIn: '1d' },
    }),
  ],
  providers: [AuthService, JwtStrategy],
})
export class AuthModule {}
```

### Guards

**Impact**: HIGH

```typescript
// roles.guard.ts
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}
  
  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.get<string[]>(
      'roles',
      context.getHandler(),
    );
    
    if (!requiredRoles) {
      return true;
    }
    
    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}

// roles.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const Roles = (...roles: string[]) => SetMetadata('roles', roles);

// Usage
@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
export class AdminController {
  @Get()
  @Roles('admin')
  findAll() {
    return this.adminService.findAll();
  }
}
```

## Database Best Practices

### Repository Pattern

**Impact**: HIGH

```typescript
// user.repository.ts
import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

@Injectable()
export class UserRepository {
  constructor(
    @InjectRepository(User)
    private readonly repository: Repository<User>,
  ) {}
  
  async findByEmail(email: string): Promise<User | null> {
    return this.repository.findOne({ 
      where: { email },
      select: ['id', 'email', 'name', 'password'] 
    });
  }
  
  async findAllActive(): Promise<User[]> {
    return this.repository.find({ 
      where: { isActive: true },
      order: { createdAt: 'DESC' }
    });
  }
}
```

### Transactions

**Impact**: CRITICAL - Data consistency

```typescript
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

@Injectable()
export class OrdersService {
  constructor(
    @InjectDataSource()
    private dataSource: DataSource,
  ) {}
  
  async createOrder(dto: CreateOrderDto): Promise<Order> {
    const queryRunner = this.dataSource.createQueryRunner();
    
    await queryRunner.connect();
    await queryRunner.startTransaction();
    
    try {
      const order = await queryRunner.manager.save(Order, dto);
      await queryRunner.manager.save(OrderItem, dto.items);
      await queryRunner.manager.update(Product, dto.productId, {
        stock: () => 'stock - 1'
      });
      
      await queryRunner.commitTransaction();
      return order;
    } catch (err) {
      await queryRunner.rollbackTransaction();
      throw err;
    } finally {
      await queryRunner.release();
    }
  }
}
```

## Performance Optimization

### Caching

**Impact**: HIGH

```typescript
import { CacheModule, CACHE_MANAGER } from '@nestjs/cache-manager';
import { Inject } from '@nestjs/common';
import { Cache } from 'cache-manager';

// Module setup
@Module({
  imports: [
    CacheModule.register({
      ttl: 300, // 5 minutes
      max: 100, // maximum items
    }),
  ],
})
export class AppModule {}

// Service usage
@Injectable()
export class UsersService {
  constructor(
    @Inject(CACHE_MANAGER)
    private cacheManager: Cache,
  ) {}
  
  async findOne(id: string): Promise<User> {
    const cacheKey = `user:${id}`;
    const cached = await this.cacheManager.get<User>(cacheKey);
    
    if (cached) {
      return cached;
    }
    
    const user = await this.userRepository.findOne({ where: { id } });
    await this.cacheManager.set(cacheKey, user);
    
    return user;
  }
}

// Or use decorator
@UseInterceptors(CacheInterceptor)
@Get(':id')
findOne(@Param('id') id: string) {
  return this.usersService.findOne(id);
}
```

### Query Optimization

```typescript
// ❌ Bad: N+1 problem
async findAll() {
  const users = await this.userRepository.find();
  // For each user, separate query
  for (const user of users) {
    user.posts = await this.postsRepository.find({ 
      where: { userId: user.id } 
    });
  }
  return users;
}

// ✅ Good: Eager loading
async findAll() {
  return this.userRepository.find({
    relations: ['posts', 'profile'],
  });
}

// ✅ Better: Query builder for complex queries
async findAll() {
  return this.userRepository
    .createQueryBuilder('user')
    .leftJoinAndSelect('user.posts', 'posts')
    .leftJoinAndSelect('user.profile', 'profile')
    .where('user.isActive = :isActive', { isActive: true })
    .orderBy('user.createdAt', 'DESC')
    .take(10)
    .getMany();
}
```

### Pagination

**Impact**: CRITICAL - For large datasets

```typescript
export class PaginationDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;
  
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 10;
}

@Get()
async findAll(@Query() paginationDto: PaginationDto) {
  const { page, limit } = paginationDto;
  
  const [items, total] = await this.userRepository.findAndCount({
    skip: (page - 1) * limit,
    take: limit,
    order: { createdAt: 'DESC' },
  });
  
  return {
    items,
    meta: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    },
  };
}
```

## Configuration Management

**Impact**: HIGH

```typescript
// config/configuration.ts
export default () => ({
  port: parseInt(process.env.PORT, 10) || 3000,
  database: {
    host: process.env.DATABASE_HOST,
    port: parseInt(process.env.DATABASE_PORT, 10) || 5432,
  },
  jwt: {
    secret: process.env.JWT_SECRET,
    expiresIn: process.env.JWT_EXPIRES_IN || '1d',
  },
});

// app.module.ts
@Module({
  imports: [
    ConfigModule.forRoot({
      load: [configuration],
      isGlobal: true,
      validationSchema: Joi.object({
        PORT: Joi.number().default(3000),
        DATABASE_HOST: Joi.string().required(),
        JWT_SECRET: Joi.string().required(),
      }),
    }),
  ],
})
export class AppModule {}

// Usage
@Injectable()
export class AppService {
  constructor(private configService: ConfigService) {}
  
  getPort(): number {
    return this.configService.get<number>('port');
  }
}
```

## Testing

### Unit Tests

```typescript
describe('UsersService', () => {
  let service: UsersService;
  let repository: Repository<User>;
  
  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(User),
          useValue: {
            find: jest.fn(),
            findOne: jest.fn(),
            save: jest.fn(),
          },
        },
      ],
    }).compile();
    
    service = module.get<UsersService>(UsersService);
    repository = module.get(getRepositoryToken(User));
  });
  
  it('should find all users', async () => {
    const users = [{ id: '1', name: 'John' }];
    jest.spyOn(repository, 'find').mockResolvedValue(users);
    
    expect(await service.findAll()).toEqual(users);
  });
});
```

### E2E Tests

```typescript
describe('Users (e2e)', () => {
  let app: INestApplication;
  
  beforeAll(async () => {
    const moduleFixture = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    
    app = moduleFixture.createNestApplication();
    await app.init();
  });
  
  it('/users (GET)', () => {
    return request(app.getHttpServer())
      .get('/users')
      .expect(200)
      .expect((res) => {
        expect(Array.isArray(res.body)).toBe(true);
      });
  });
  
  afterAll(async () => {
    await app.close();
  });
});
```

## Common Pitfalls

### 1. Not Using DTOs

Always validate input with DTOs.

### 2. Circular Dependencies

```typescript
// ❌ Bad: Circular dependency
@Module({
  imports: [forwardRef(() => UsersModule)],
})
export class AuthModule {}

// ✅ Good: Extract shared logic to separate module
@Module({
  exports: [SharedService],
})
export class SharedModule {}
```

### 3. Not Handling Promises

```typescript
// ❌ Bad: Unhandled promise
async someMethod() {
  this.repository.save(data); // Not awaited!
}

// ✅ Good
async someMethod() {
  await this.repository.save(data);
}
```

### 4. Exposing Sensitive Data

```typescript
// ❌ Bad: Password in response
@Get(':id')
async findOne(@Param('id') id: string) {
  return this.userRepository.findOne({ where: { id } });
}

// ✅ Good: Exclude password
import { Exclude } from 'class-transformer';

export class User {
  id: string;
  email: string;
  
  @Exclude()
  password: string;
}

// In main.ts
app.useGlobalInterceptors(new ClassSerializerInterceptor(app.get(Reflector)));
```

## Security Checklist

- [ ] Use helmet for security headers
- [ ] Enable CORS properly
- [ ] Implement rate limiting
- [ ] Validate all inputs with DTOs
- [ ] Use parameterized queries (TypeORM does this)
- [ ] Hash passwords with bcrypt
- [ ] Use environment variables for secrets
- [ ] Implement proper error handling (don't expose stack traces)
- [ ] Use HTTPS in production
- [ ] Implement authentication & authorization

## References

- [NestJS Documentation](https://docs.nestjs.com)
- [TypeORM Best Practices](https://typeorm.io)
- [OWASP API Security](https://owasp.org/www-project-api-security/)

## Attribution

Community-curated best practices from NestJS experts and official documentation.
