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
exports.UsersController = void 0;
const common_1 = require("@nestjs/common");
const store_service_1 = require("../core/store.service");
const update_me_dto_1 = require("./dto/update-me.dto");
let UsersController = class UsersController {
    storeService;
    constructor(storeService) {
        this.storeService = storeService;
    }
    async getMe(authorization) {
        return this.storeService.getUserFromAuthHeader(authorization);
    }
    async updateMe(authorization, body) {
        const user = await this.storeService.getUserFromAuthHeader(authorization);
        return this.storeService.updateUser(user.id, {
            displayName: body?.displayName,
            avatarUrl: body?.avatarUrl,
            bio: body?.bio,
        });
    }
};
exports.UsersController = UsersController;
__decorate([
    (0, common_1.Get)('me'),
    __param(0, (0, common_1.Headers)('authorization')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "getMe", null);
__decorate([
    (0, common_1.Patch)('me'),
    __param(0, (0, common_1.Headers)('authorization')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_me_dto_1.UpdateMeDto]),
    __metadata("design:returntype", Promise)
], UsersController.prototype, "updateMe", null);
exports.UsersController = UsersController = __decorate([
    (0, common_1.Controller)('v1/users'),
    __metadata("design:paramtypes", [store_service_1.StoreService])
], UsersController);
//# sourceMappingURL=users.controller.js.map