"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.HttpExceptionFilter = void 0;
const common_1 = require("@nestjs/common");
let HttpExceptionFilter = class HttpExceptionFilter {
    catch(exception, host) {
        const context = host.switchToHttp();
        const response = context.getResponse();
        const request = context.getRequest();
        const status = exception instanceof common_1.HttpException
            ? exception.getStatus()
            : common_1.HttpStatus.INTERNAL_SERVER_ERROR;
        const payload = exception instanceof common_1.HttpException
            ? exception.getResponse()
            : { message: 'Internal server error' };
        const message = this.resolveMessage(payload);
        const details = this.resolveDetails(payload);
        response.status(status).json({
            success: false,
            error: {
                code: this.codeFromStatus(status),
                message,
                details,
                timestamp: new Date().toISOString(),
                path: request.url,
            },
        });
    }
    resolveMessage(payload) {
        if (typeof payload === 'string') {
            return payload;
        }
        if (this.hasMessage(payload)) {
            const { message } = payload;
            if (Array.isArray(message)) {
                return message.join(', ');
            }
            if (typeof message === 'string') {
                return message;
            }
        }
        return 'Request failed';
    }
    resolveDetails(payload) {
        if (typeof payload === 'object' && payload !== null) {
            return payload;
        }
        return null;
    }
    codeFromStatus(status) {
        if (status >= 500) {
            return 'INTERNAL_ERROR';
        }
        if (status === 429) {
            return 'RATE_LIMITED';
        }
        if (status === 401) {
            return 'UNAUTHORIZED';
        }
        if (status === 404) {
            return 'NOT_FOUND';
        }
        if (status >= 400) {
            return 'BAD_REQUEST';
        }
        return 'UNKNOWN_ERROR';
    }
    hasMessage(payload) {
        return typeof payload === 'object' && payload !== null && 'message' in payload;
    }
};
exports.HttpExceptionFilter = HttpExceptionFilter;
exports.HttpExceptionFilter = HttpExceptionFilter = __decorate([
    (0, common_1.Catch)()
], HttpExceptionFilter);
//# sourceMappingURL=http-exception.filter.js.map