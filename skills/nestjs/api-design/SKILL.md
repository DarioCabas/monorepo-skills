---
name: nestjs-api-design
description: RESTful API design best practices for NestJS including versioning, documentation, error responses, and OpenAPI/Swagger integration.
license: MIT
metadata:
  author: Community
  tags: nestjs, api, rest, openapi, swagger, versioning
---

# NestJS API Design

## Overview

Best practices for designing clean, maintainable, and well-documented RESTful APIs with NestJS, including proper HTTP methods, status codes, versioning, and OpenAPI documentation.

## When to Apply

Use when:
- Designing new REST APIs
- Documenting existing APIs
- Implementing API versioning
- Standardizing error responses
- Creating public APIs

## Quick Reference

### HTTP Methods & Status Codes

**Impact**: CRITICAL - Follow REST conventions

```typescript
@Controller('users')
export class UsersController {
  // GET - 200 OK
  @Get()
  @HttpCode(200)
  async findAll(): Promise<User[]> {
    return this.usersService.findAll();
  }
  
  // GET - 200 OK or 404 Not Found
  @Get(':id')
  async findOne(@Param('id') id: string): Promise<User> {
    const user = await this.usersService.findOne(id);
    if (!user) {
      throw new NotFoundException(`User ${id} not found`);
    }
    return user;
  }
  
  // POST - 201 Created
  @Post()
  @HttpCode(201)
  async create(@Body() dto: CreateUserDto): Promise<User> {
    return this.usersService.create(dto);
  }
  
  // PUT - 200 OK or 404 Not Found
  @Put(':id')
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateUserDto,
  ): Promise<User> {
    return this.usersService.update(id, dto);
  }
  
  // PATCH - 200 OK
  @Patch(':id')
  async partialUpdate(
    @Param('id') id: string,
    @Body() dto: Partial<UpdateUserDto>,
  ): Promise<User> {
    return this.usersService.update(id, dto);
  }
  
  // DELETE - 204 No Content
  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id') id: string): Promise<void> {
    await this.usersService.remove(id);
  }
}
```

### Standardized Error Responses

**Impact**: HIGH

```typescript
// custom-exception.filter.ts
import { 
  ExceptionFilter, 
  Catch, 
  ArgumentsHost, 
  HttpException,
  HttpStatus 
} from '@nestjs/common';

export interface ErrorResponse {
  statusCode: number;
  message: string | string[];
  error: string;
  timestamp: string;
  path: string;
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();
    
    const status = exception instanceof HttpException
      ? exception.getStatus()
      : HttpStatus.INTERNAL_SERVER_ERROR;
    
    const message = exception instanceof HttpException
      ? exception.message
      : 'Internal server error';
    
    const errorResponse: ErrorResponse = {
      statusCode: status,
      message,
      error: HttpStatus[status],
      timestamp: new Date().toISOString(),
      path: request.url,
    };
    
    response.status(status).json(errorResponse);
  }
}
```

### Response Serialization

**Impact**: HIGH

```typescript
// response.interceptor.ts
import { 
  Injectable, 
  NestInterceptor, 
  ExecutionContext, 
  CallHandler 
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

export interface Response<T> {
  data: T;
  meta?: {
    timestamp: string;
    [key: string]: any;
  };
}

@Injectable()
export class ResponseInterceptor<T> implements NestInterceptor<T, Response<T>> {
  intercept(context: ExecutionContext, next: CallHandler): Observable<Response<T>> {
    return next.handle().pipe(
      map(data => ({
        data,
        meta: {
          timestamp: new Date().toISOString(),
        },
      })),
    );
  }
}

// Usage
@UseInterceptors(ResponseInterceptor)
@Controller('users')
export class UsersController {}
```

## API Versioning

### URI Versioning (Recommended)

**Impact**: HIGH

```typescript
// main.ts
app.enableVersioning({
  type: VersioningType.URI,
  defaultVersion: '1',
});

// users.controller.ts
@Controller({
  path: 'users',
  version: '1',
})
export class UsersV1Controller {
  @Get()
  findAll() {
    return this.usersService.findAll();
  }
}

@Controller({
  path: 'users',
  version: '2',
})
export class UsersV2Controller {
  @Get()
  findAll() {
    // New implementation with different response format
    return this.usersService.findAllV2();
  }
}

// URLs:
// GET /v1/users
// GET /v2/users
```

### Header Versioning

```typescript
app.enableVersioning({
  type: VersioningType.HEADER,
  header: 'X-API-Version',
});

// Request:
// GET /users
// X-API-Version: 1
```

## OpenAPI/Swagger Documentation

**Impact**: CRITICAL - API documentation

```bash
npm install @nestjs/swagger swagger-ui-express
```

```typescript
// main.ts
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';

const config = new DocumentBuilder()
  .setTitle('Users API')
  .setDescription('The users API description')
  .setVersion('1.0')
  .addBearerAuth()
  .addTag('users')
  .build();

const document = SwaggerModule.createDocument(app, config);
SwaggerModule.setup('api', app, document);

// Available at http://localhost:3000/api
```

### Decorating Controllers

```typescript
import { 
  ApiTags, 
  ApiOperation, 
  ApiResponse,
  ApiBearerAuth 
} from '@nestjs/swagger';

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  @Get()
  @ApiOperation({ summary: 'Get all users' })
  @ApiResponse({ 
    status: 200, 
    description: 'Return all users',
    type: [User],
  })
  findAll(): Promise<User[]> {
    return this.usersService.findAll();
  }
  
  @Post()
  @ApiOperation({ summary: 'Create user' })
  @ApiResponse({ 
    status: 201, 
    description: 'User created successfully',
    type: User,
  })
  @ApiResponse({ 
    status: 400, 
    description: 'Invalid input' 
  })
  create(@Body() dto: CreateUserDto): Promise<User> {
    return this.usersService.create(dto);
  }
}
```

### Documenting DTOs

```typescript
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateUserDto {
  @ApiProperty({
    description: 'User full name',
    example: 'John Doe',
    minLength: 2,
    maxLength: 100,
  })
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name: string;
  
  @ApiProperty({
    description: 'User email address',
    example: 'john@example.com',
  })
  @IsEmail()
  email: string;
  
  @ApiPropertyOptional({
    description: 'User age',
    example: 25,
    minimum: 18,
  })
  @IsOptional()
  @IsInt()
  @Min(18)
  age?: number;
}
```

### Documenting Responses

```typescript
import { ApiExtraModels, getSchemaPath } from '@nestjs/swagger';

export class PaginatedResponse<T> {
  @ApiProperty({ type: 'array', items: {} })
  items: T[];
  
  @ApiProperty()
  meta: {
    total: number;
    page: number;
    limit: number;
    totalPages: number;
  };
}

@ApiExtraModels(PaginatedResponse, User)
@Get()
@ApiResponse({
  status: 200,
  schema: {
    allOf: [
      { $ref: getSchemaPath(PaginatedResponse) },
      {
        properties: {
          items: {
            type: 'array',
            items: { $ref: getSchemaPath(User) },
          },
        },
      },
    ],
  },
})
findAll(): Promise<PaginatedResponse<User>> {
  return this.usersService.findAll();
}
```

## Request Validation

### Query Parameters

```typescript
export class FindUsersDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;
  
  @ApiPropertyOptional({ enum: ['active', 'inactive'] })
  @IsOptional()
  @IsEnum(['active', 'inactive'])
  status?: 'active' | 'inactive';
  
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number = 1;
  
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number = 10;
}

@Get()
findAll(@Query() query: FindUsersDto) {
  return this.usersService.findAll(query);
}
```

### Path Parameters

```typescript
export class FindOneParams {
  @ApiProperty()
  @IsUUID()
  id: string;
}

@Get(':id')
findOne(@Param() params: FindOneParams) {
  return this.usersService.findOne(params.id);
}
```

## Rate Limiting

**Impact**: CRITICAL - Prevent abuse

```bash
npm install @nestjs/throttler
```

```typescript
// app.module.ts
@Module({
  imports: [
    ThrottlerModule.forRoot([{
      ttl: 60000, // 1 minute
      limit: 10,  // 10 requests per minute
    }]),
  ],
})
export class AppModule {}

// Global guard
app.useGlobalGuards(new ThrottlerGuard());

// Per-route customization
@Throttle({ default: { limit: 3, ttl: 60000 } })
@Post('login')
login(@Body() dto: LoginDto) {
  return this.authService.login(dto);
}
```

## CORS Configuration

```typescript
// main.ts
app.enableCors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
  credentials: true,
});
```

## Health Checks

**Impact**: HIGH - Monitoring

```bash
npm install @nestjs/terminus
```

```typescript
// health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { 
  HealthCheck, 
  HealthCheckService, 
  TypeOrmHealthIndicator,
  MemoryHealthIndicator 
} from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
    private memory: MemoryHealthIndicator,
  ) {}
  
  @Get()
  @HealthCheck()
  check() {
    return this.health.check([
      () => this.db.pingCheck('database'),
      () => this.memory.checkHeap('memory_heap', 150 * 1024 * 1024),
    ]);
  }
}
```

## Filtering, Sorting, Searching

```typescript
export class QueryDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  search?: string;
  
  @ApiPropertyOptional({ example: 'createdAt:desc' })
  @IsOptional()
  @IsString()
  sort?: string;
  
  @ApiPropertyOptional({ example: 'name,email' })
  @IsOptional()
  @IsString()
  fields?: string;
}

@Get()
async findAll(@Query() query: QueryDto) {
  const queryBuilder = this.userRepository
    .createQueryBuilder('user');
  
  // Search
  if (query.search) {
    queryBuilder.where(
      'user.name ILIKE :search OR user.email ILIKE :search',
      { search: `%${query.search}%` }
    );
  }
  
  // Sort
  if (query.sort) {
    const [field, order] = query.sort.split(':');
    queryBuilder.orderBy(`user.${field}`, order === 'desc' ? 'DESC' : 'ASC');
  }
  
  // Select fields
  if (query.fields) {
    const fields = query.fields.split(',').map(f => `user.${f}`);
    queryBuilder.select(fields);
  }
  
  return queryBuilder.getMany();
}
```

## API Best Practices Checklist

- [ ] Use proper HTTP methods and status codes
- [ ] Implement consistent error responses
- [ ] Add request validation with DTOs
- [ ] Document API with OpenAPI/Swagger
- [ ] Implement API versioning
- [ ] Add rate limiting
- [ ] Configure CORS properly
- [ ] Implement health checks
- [ ] Use pagination for list endpoints
- [ ] Add filtering and sorting
- [ ] Implement authentication/authorization
- [ ] Use proper logging
- [ ] Add request/response serialization
- [ ] Handle errors gracefully
- [ ] Use meaningful resource names

## Common Pitfalls

### 1. Inconsistent Naming

```typescript
// ❌ Bad: Inconsistent
@Get('/get-all-users')
@Post('/createNewUser')
@Delete('/removeUserById/:id')

// ✅ Good: RESTful
@Get()
@Post()
@Delete(':id')
```

### 2. Not Using DTOs for Query Parameters

Always validate query params with DTOs.

### 3. Returning Raw Database Entities

Use serialization to control response shape.

### 4. Not Documenting Breaking Changes

Use versioning and maintain changelog.

## Resources

- [REST API Best Practices](https://restfulapi.net/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [NestJS OpenAPI](https://docs.nestjs.com/openapi/introduction)

## Attribution

Community-curated best practices for API design with NestJS.
