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
exports.RoomsController = void 0;
const common_1 = require("@nestjs/common");
const store_service_1 = require("../core/store.service");
const create_room_dto_1 = require("./dto/create-room.dto");
let RoomsController = class RoomsController {
    storeService;
    constructor(storeService) {
        this.storeService = storeService;
    }
    async listRooms() {
        return this.storeService.listRooms();
    }
    async createRoom(authorization, body) {
        const user = await this.storeService.getUserFromAuthHeader(authorization);
        return this.storeService.createRoom(user.id, body?.title);
    }
    async joinRoom(authorization, roomId) {
        await this.storeService.getUserFromAuthHeader(authorization);
        return this.storeService.joinRoom(roomId);
    }
};
exports.RoomsController = RoomsController;
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], RoomsController.prototype, "listRooms", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Headers)('authorization')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, create_room_dto_1.CreateRoomDto]),
    __metadata("design:returntype", Promise)
], RoomsController.prototype, "createRoom", null);
__decorate([
    (0, common_1.Post)(':roomId/join'),
    __param(0, (0, common_1.Headers)('authorization')),
    __param(1, (0, common_1.Param)('roomId', new common_1.ParseUUIDPipe())),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, String]),
    __metadata("design:returntype", Promise)
], RoomsController.prototype, "joinRoom", null);
exports.RoomsController = RoomsController = __decorate([
    (0, common_1.Controller)('v1/rooms'),
    __metadata("design:paramtypes", [store_service_1.StoreService])
], RoomsController);
//# sourceMappingURL=rooms.controller.js.map