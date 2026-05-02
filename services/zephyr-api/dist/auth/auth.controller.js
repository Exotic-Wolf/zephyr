"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const common_1 = require("@nestjs/common");
const store_service_1 = require("../core/store.service");
const guest_login_dto_1 = require("./dto/guest-login.dto");
const google_login_dto_1 = require("./dto/google-login.dto");
const apple_login_dto_1 = require("./dto/apple-login.dto");
let AuthController = class AuthController {
    storeService;
    constructor(storeService) {
        this.storeService = storeService;
    }
    async guestLogin(body) {
        return this.storeService.issueGuestSession(body?.displayName);
    }
    async googleLogin(body) {
        return this.storeService.issueGoogleSession(body.idToken);
    }
    async appleLogin(body) {
        return this.storeService.issueAppleSession(body.idToken, {
            givenName: body.givenName,
            familyName: body.familyName,
            email: body.email,
        });
    }
};
exports.AuthController = AuthController;
__decorate([
    (0, common_1.Post)('guest-login'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [guest_login_dto_1.GuestLoginDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "guestLogin", null);
__decorate([
    (0, common_1.Post)('google-login'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [google_login_dto_1.GoogleLoginDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "googleLogin", null);
__decorate([
    (0, common_1.Post)('apple-login'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [apple_login_dto_1.AppleLoginDto]),
    __metadata("design:returntype", Promise)
], AuthController.prototype, "appleLogin", null);
exports.AuthController = AuthController = __decorate([
    (0, common_1.Controller)('v1/auth'),
    __metadata("design:paramtypes", [store_service_1.StoreService])
], AuthController);
//# sourceMappingURL=auth.controller.js.map