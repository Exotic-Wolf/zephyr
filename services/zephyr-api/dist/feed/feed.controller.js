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
exports.FeedController = void 0;
const common_1 = require("@nestjs/common");
const store_service_1 = require("../core/store.service");
let FeedController = class FeedController {
    storeService;
    constructor(storeService) {
        this.storeService = storeService;
    }
    async listLiveFeed(authorization, limit) {
        await this.storeService.getUserFromAuthHeader(authorization);
        return this.storeService.listLiveFeed(limit);
    }
};
exports.FeedController = FeedController;
__decorate([
    (0, common_1.Get)('live'),
    __param(0, (0, common_1.Headers)('authorization')),
    __param(1, (0, common_1.Query)('limit', new common_1.DefaultValuePipe(20), common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, Number]),
    __metadata("design:returntype", Promise)
], FeedController.prototype, "listLiveFeed", null);
exports.FeedController = FeedController = __decorate([
    (0, common_1.Controller)('v1/feed'),
    __metadata("design:paramtypes", [store_service_1.StoreService])
], FeedController);
//# sourceMappingURL=feed.controller.js.map