// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get goLiveInSeconds => 'Entre ao vivo em segundos';

  @override
  String get checkingApi => 'Verificando API...';

  @override
  String get apiConnected => 'API Conectada';

  @override
  String get apiOffline => 'API Offline';

  @override
  String get refreshApiStatus => 'Atualizar status da API';

  @override
  String get connecting => 'Conectando...';

  @override
  String get continueAsGuest => 'Continuar como Convidado';

  @override
  String get signingIn => 'Entrando...';

  @override
  String get continueWithGoogle => 'Continuar com Google';

  @override
  String get continueWithApple => 'Continuar com Apple';

  @override
  String get home => 'Início';

  @override
  String get live => 'Ao Vivo';

  @override
  String get explore => 'Explorar';

  @override
  String get inbox => 'Mensagens';

  @override
  String get me => 'Eu';

  @override
  String get noOneIsLiveRightNow =>
      'Ninguém está ao vivo agora. Verifique em um momento.';

  @override
  String noResultsFor(String query) {
    return 'Nenhum resultado para \"$query\".';
  }

  @override
  String noOneIsLiveFrom(String location) {
    return 'Ninguém está ao vivo de $location agora.';
  }

  @override
  String get popular => 'Popular';

  @override
  String get discover => 'Descobrir';

  @override
  String get follow => 'Seguir';

  @override
  String get noPopularStreamersRightNow =>
      'Nenhum streamer popular agora. Verifique em breve.';

  @override
  String noStreamersFrom(String location) {
    return 'Nenhum streamer de $location agora.';
  }

  @override
  String noneOfPeopleYouFollowAreLive(String location) {
    return 'Ninguém que você segue está ao vivo de $location agora.';
  }

  @override
  String get followSomeoneToSeeThemHere => 'Siga alguém para vê-lo aqui.';

  @override
  String get openingLive => 'Abrindo ao vivo...';

  @override
  String get randomMatch => 'Parceiro aleatório';

  @override
  String get goLive => 'Ir ao Vivo';

  @override
  String get startLiveStreamAndConnect =>
      'Inicie uma transmissão ao vivo e conecte-se\ncom seu público em tempo real';

  @override
  String get starting => 'Iniciando…';

  @override
  String get startLiveStream => 'Iniciar Transmissão';

  @override
  String get level => 'Nível';

  @override
  String levelValue(int level) {
    return 'Nível $level';
  }

  @override
  String get keepStreamingToLevelUp =>
      'Continue transmitindo, recebendo presentes e interagindo para subir de nível.';

  @override
  String get myBalance => 'Meu Saldo';

  @override
  String get coinBalance => 'Saldo de Moedas';

  @override
  String coinsAmount(int coins) {
    return '$coins moedas';
  }

  @override
  String get buyCoins => 'Comprar Moedas';

  @override
  String coinPackLabel(int coins, String label) {
    return '$coins moedas • $label';
  }

  @override
  String get buying => 'Comprando...';

  @override
  String get buy => 'Comprar';

  @override
  String get myRevenue => 'Minha Receita';

  @override
  String get revenueFromGiftsAndCalls =>
      'Receita de presentes e chamadas pagas aparece aqui.';

  @override
  String get settings => 'Configurações';

  @override
  String get account => 'Conta';

  @override
  String get privacy => 'Privacidade';

  @override
  String get notifications => 'Notificações';

  @override
  String get language => 'Idioma';

  @override
  String get appearance => 'Aparência';

  @override
  String get search => 'Pesquisar';

  @override
  String get closeSearch => 'Fechar pesquisa';

  @override
  String get nameOrId => 'Nome ou ID…';

  @override
  String get refresh => 'Atualizar';

  @override
  String get logout => 'Sair';

  @override
  String get systemDefault => 'Padrão do sistema';

  @override
  String get followDeviceSetting => 'Seguir configuração do dispositivo';

  @override
  String get lightMode => 'Claro';

  @override
  String get alwaysUseLightMode => 'Sempre usar modo claro';

  @override
  String get darkMode => 'Escuro';

  @override
  String get alwaysUseDarkMode => 'Sempre usar modo escuro';

  @override
  String get owner => 'PROPRIETÁRIO';

  @override
  String get callSessionStarted =>
      'Sessão de chamada iniciada. Cobrança ativa.';

  @override
  String get notEnoughCoinsForRandomMatch =>
      'Moedas insuficientes para parceiro aleatório. Recarregue primeiro.';

  @override
  String get noReceiverAvailable =>
      'Nenhum receptor disponível para chamada direta. Tente o modo Aleatório.';

  @override
  String get callEndedInsufficientBalance =>
      'Chamada encerrada: saldo insuficiente.';

  @override
  String get callEnded => 'Chamada encerrada.';

  @override
  String get noMessagesYet => 'Nenhuma mensagem ainda';

  @override
  String get noMessagesYetSayHello => 'Nenhuma mensagem ainda. Diga olá!';

  @override
  String get messageHint => 'Mensagem…';

  @override
  String failedToSend(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String get findAnyoneByNameOrId =>
      'Encontre qualquer pessoa pelo nome ou ID de 8 dígitos';

  @override
  String get nameOrIdHint => 'Nome ou ID de 8 dígitos…';

  @override
  String get discoverPeople => 'Descobrir pessoas';

  @override
  String get searchByNameOrId =>
      'Pesquise pelo nome ou insira\num ID público de 8 dígitos';

  @override
  String get noUsersFound => 'Nenhum usuário encontrado';

  @override
  String get tryDifferentNameOrId => 'Tente um nome ou ID diferente';

  @override
  String get myProfile => 'Meu Perfil';

  @override
  String get save => 'Salvar';

  @override
  String get edit => 'Editar';

  @override
  String get id => 'ID';

  @override
  String get idCopiedToClipboard => 'ID copiado';

  @override
  String get nickname => 'Apelido';

  @override
  String get enterNickname => 'Digite um apelido';

  @override
  String get gender => 'Gênero';

  @override
  String get male => 'Masculino';

  @override
  String get female => 'Feminino';

  @override
  String get nonBinary => 'Não-binário';

  @override
  String get preferNotToSay => 'Prefiro não dizer';

  @override
  String get birthday => 'Data de nascimento';

  @override
  String get notSet => 'Não definido';

  @override
  String get country => 'País';

  @override
  String get yourIdIsPermanent =>
      'Seu ID é permanente e não pode ser alterado.';

  @override
  String get viewPublicProfile => 'Ver Perfil Público';

  @override
  String get takePhoto => 'Tirar Foto';

  @override
  String get chooseFromLibrary => 'Escolher da Biblioteca';

  @override
  String get ownerBadge => '👑  PROPRIETÁRIO';

  @override
  String get avatarUpdated => 'Avatar atualizado';

  @override
  String uploadFailed(String error) {
    return 'Falha no upload: $error';
  }

  @override
  String get profileSaved => 'Perfil salvo';

  @override
  String failedToSaveProfile(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get myCallPrice => 'Meu Preço de Chamada';

  @override
  String get spark => 'Faísca';

  @override
  String get youEarnSparks =>
      'Você ganha Faíscas a cada segundo em uma chamada';

  @override
  String get fairPricingGetsMoreCalls =>
      'Preços justos geram mais chamadas, mais rápido';

  @override
  String get callersWillSee => 'Quem ligar verá:';

  @override
  String get videoCall => 'Videochamada';

  @override
  String get perMinute => '/min';

  @override
  String get chooseYourRate => 'Escolha sua tarifa';

  @override
  String yourLevelIs(int level) {
    return 'Seu nível é $level. Níveis mais altos desbloqueiam em níveis maiores.';
  }

  @override
  String get tier => 'Nível';

  @override
  String get youEarn => 'Você ganha';

  @override
  String get callerPays => 'Quem liga paga';

  @override
  String get callRateSaved => 'Tarifa de chamada salva';

  @override
  String failedToSaveRate(String error) {
    return 'Falha ao salvar: $error';
  }

  @override
  String get lockedTiersUnlock =>
      'Níveis bloqueados são liberados conforme você sobe de nível sendo ativo no Zephyr.';

  @override
  String videoCallWithRate(String rate) {
    return 'Videochamada $rate';
  }

  @override
  String get messageButton => 'Mensagem';

  @override
  String get notAvailable => 'Não disponível';

  @override
  String get currentlyBusy => 'Ocupado agora';

  @override
  String get followers => 'Seguidores';

  @override
  String get followButton => 'Seguir';

  @override
  String get followingButton => 'Seguindo';

  @override
  String get about => 'Sobre';

  @override
  String get noBioYet => 'Sem biografia ainda.';

  @override
  String get gifts => 'Presentes';

  @override
  String get noGiftsYet => 'Sem presentes ainda.';

  @override
  String get getReady => 'Prepare-se!';

  @override
  String get startingYourStream => 'Iniciando sua transmissão…';

  @override
  String get cancel => 'Cancelar';

  @override
  String get liveIndicator => 'AO VIVO';

  @override
  String get endLive => 'Encerrar ao vivo?';

  @override
  String get streamWillEndMessage =>
      'Sua transmissão será encerrada e os espectadores serão desconectados.';

  @override
  String get endLiveButton => 'Encerrar';

  @override
  String get startingCamera => 'Iniciando câmera…';

  @override
  String get cameraIsOff => 'Câmera desligada';

  @override
  String get micOn => 'Microfone ligado';

  @override
  String get micOff => 'Microfone desligado';

  @override
  String get camera => 'Câmera';

  @override
  String get off => 'Desligado';

  @override
  String get flip => 'Virar';

  @override
  String totalWatching(int total) {
    return '$total assistindo';
  }

  @override
  String get noViewersYet => 'Nenhum espectador ainda';

  @override
  String andMoreWatching(int count) {
    return 'e mais $count assistindo…';
  }

  @override
  String get saySomething => 'Diga algo…';

  @override
  String get welcomeToLive => 'Bem-vindo ao meu ao vivo! 👋';
}
