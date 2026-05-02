"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const helmet_1 = __importDefault(require("helmet"));
const app_module_1 = require("./app.module");
const http_exception_filter_1 = require("./common/filters/http-exception.filter");
function validateEnvironment() {
    if (process.env.NODE_ENV !== 'production') {
        return;
    }
    const requiredVars = ['JWT_SECRET', 'DATABASE_URL', 'CORS_ORIGINS'];
    const missingVars = requiredVars.filter((name) => !process.env[name]);
    if (missingVars.length > 0) {
        throw new Error(`Missing required environment variables in production: ${missingVars.join(', ')}`);
    }
}
function parseCorsOrigins() {
    const rawOrigins = process.env.CORS_ORIGINS?.trim();
    if (!rawOrigins) {
        return ['http://localhost:3000'];
    }
    return rawOrigins
        .split(',')
        .map((origin) => origin.trim())
        .filter((origin) => origin.length > 0);
}
async function bootstrap() {
    validateEnvironment();
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    const isProduction = process.env.NODE_ENV === 'production';
    const corsOrigins = parseCorsOrigins();
    app.enableCors({
        origin: (requestOrigin, callback) => {
            if (!requestOrigin) {
                callback(null, true);
                return;
            }
            if (corsOrigins.includes(requestOrigin)) {
                callback(null, true);
                return;
            }
            callback(new Error('CORS origin not allowed'), false);
        },
        credentials: true,
    });
    app.use((0, helmet_1.default)({
        crossOriginResourcePolicy: false,
        contentSecurityPolicy: false,
    }));
    const httpAdapter = app.getHttpAdapter().getInstance();
    httpAdapter.disable('x-powered-by');
    if (isProduction) {
        httpAdapter.set('trust proxy', 1);
    }
    app.useGlobalPipes(new common_1.ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
    }));
    app.useGlobalFilters(new http_exception_filter_1.HttpExceptionFilter());
    await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
//# sourceMappingURL=main.js.map