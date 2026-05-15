// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get goLiveInSeconds => 'Transmite en segundos';

  @override
  String get checkingApi => 'Verificando API...';

  @override
  String get apiConnected => 'API Conectada';

  @override
  String get apiOffline => 'API sin conexión';

  @override
  String get refreshApiStatus => 'Actualizar estado de la API';

  @override
  String get connecting => 'Conectando...';

  @override
  String get continueAsGuest => 'Continuar como Invitado';

  @override
  String get signingIn => 'Iniciando sesión...';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get continueWithApple => 'Continuar con Apple';

  @override
  String get home => 'Inicio';

  @override
  String get live => 'En Vivo';

  @override
  String get explore => 'Explorar';

  @override
  String get inbox => 'Mensajes';

  @override
  String get me => 'Yo';

  @override
  String get noOneIsLiveRightNow =>
      'Nadie está en vivo ahora. Comprueba de nuevo en un momento.';

  @override
  String noResultsFor(String query) {
    return 'Sin resultados para \"$query\".';
  }

  @override
  String noOneIsLiveFrom(String location) {
    return 'Nadie está en vivo desde $location ahora.';
  }

  @override
  String get popular => 'Popular';

  @override
  String get discover => 'Descubrir';

  @override
  String get follow => 'Seguir';

  @override
  String get noPopularStreamersRightNow =>
      'No hay streamers populares ahora. Comprueba pronto.';

  @override
  String noStreamersFrom(String location) {
    return 'No hay streamers desde $location ahora.';
  }

  @override
  String noneOfPeopleYouFollowAreLive(String location) {
    return 'Nadie a quien sigues está en vivo desde $location ahora.';
  }

  @override
  String get followSomeoneToSeeThemHere => 'Sigue a alguien para verlo aquí.';

  @override
  String get openingLive => 'Abriendo en vivo...';

  @override
  String get randomMatch => 'Pareja aleatoria';

  @override
  String get goLive => 'Ir en Vivo';

  @override
  String get startLiveStreamAndConnect =>
      'Inicia una transmisión en vivo y conecta\ncon tu audiencia en tiempo real';

  @override
  String get starting => 'Iniciando…';

  @override
  String get startLiveStream => 'Iniciar Transmisión';

  @override
  String get level => 'Nivel';

  @override
  String levelValue(int level) {
    return 'Nivel $level';
  }

  @override
  String get keepStreamingToLevelUp =>
      'Sigue transmitiendo, recibiendo regalos e interactuando para subir de nivel.';

  @override
  String get myBalance => 'Mi Saldo';

  @override
  String get coinBalance => 'Saldo de Monedas';

  @override
  String coinsAmount(int coins) {
    return '$coins monedas';
  }

  @override
  String get buyCoins => 'Comprar Monedas';

  @override
  String coinPackLabel(int coins, String label) {
    return '$coins monedas • $label';
  }

  @override
  String get buying => 'Comprando...';

  @override
  String get buy => 'Comprar';

  @override
  String get myRevenue => 'Mis Ingresos';

  @override
  String get revenueFromGiftsAndCalls =>
      'Los ingresos de regalos y llamadas pagas aparecen aquí.';

  @override
  String get settings => 'Configuración';

  @override
  String get account => 'Cuenta';

  @override
  String get privacy => 'Privacidad';

  @override
  String get notifications => 'Notificaciones';

  @override
  String get language => 'Idioma';

  @override
  String get appearance => 'Apariencia';

  @override
  String get search => 'Buscar';

  @override
  String get closeSearch => 'Cerrar búsqueda';

  @override
  String get nameOrId => 'Nombre o ID…';

  @override
  String get refresh => 'Actualizar';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get systemDefault => 'Predeterminado del sistema';

  @override
  String get followDeviceSetting => 'Seguir configuración del dispositivo';

  @override
  String get lightMode => 'Claro';

  @override
  String get alwaysUseLightMode => 'Usar siempre el modo claro';

  @override
  String get darkMode => 'Oscuro';

  @override
  String get alwaysUseDarkMode => 'Usar siempre el modo oscuro';

  @override
  String get owner => 'PROPIETARIO';

  @override
  String get callSessionStarted =>
      'Sesión de llamada iniciada. Facturación activa.';

  @override
  String get notEnoughCoinsForRandomMatch =>
      'Monedas insuficientes para pareja aleatoria. Recarga primero.';

  @override
  String get noReceiverAvailable =>
      'No hay receptor disponible para llamada directa. Prueba el modo Aleatorio.';

  @override
  String get callEndedInsufficientBalance =>
      'Llamada finalizada: saldo insuficiente.';

  @override
  String get callEnded => 'Llamada finalizada.';

  @override
  String get noMessagesYet => 'Sin mensajes aún';

  @override
  String get noMessagesYetSayHello => 'Sin mensajes aún. ¡Di hola!';

  @override
  String get messageHint => 'Mensaje…';

  @override
  String failedToSend(String error) {
    return 'Error al enviar: $error';
  }

  @override
  String get findAnyoneByNameOrId =>
      'Encuentra a cualquiera por nombre o ID de 8 dígitos';

  @override
  String get nameOrIdHint => 'Nombre o ID de 8 dígitos…';

  @override
  String get discoverPeople => 'Descubrir personas';

  @override
  String get searchByNameOrId =>
      'Busca por nombre o ingresa\nun ID público de 8 dígitos';

  @override
  String get noUsersFound => 'No se encontraron usuarios';

  @override
  String get tryDifferentNameOrId => 'Prueba un nombre o ID diferente';

  @override
  String get myProfile => 'Mi Perfil';

  @override
  String get save => 'Guardar';

  @override
  String get edit => 'Editar';

  @override
  String get id => 'ID';

  @override
  String get idCopiedToClipboard => 'ID copiado';

  @override
  String get nickname => 'Apodo';

  @override
  String get enterNickname => 'Ingresa un apodo';

  @override
  String get gender => 'Género';

  @override
  String get male => 'Masculino';

  @override
  String get female => 'Femenino';

  @override
  String get nonBinary => 'No binario';

  @override
  String get preferNotToSay => 'Prefiero no decir';

  @override
  String get birthday => 'Fecha de nacimiento';

  @override
  String get notSet => 'No definido';

  @override
  String get country => 'País';

  @override
  String get yourIdIsPermanent => 'Tu ID es permanente y no puede cambiarse.';

  @override
  String get viewPublicProfile => 'Ver Perfil Público';

  @override
  String get takePhoto => 'Tomar Foto';

  @override
  String get chooseFromLibrary => 'Elegir de la Biblioteca';

  @override
  String get ownerBadge => '👑  PROPIETARIO';

  @override
  String get avatarUpdated => 'Avatar actualizado';

  @override
  String uploadFailed(String error) {
    return 'Error al subir: $error';
  }

  @override
  String get profileSaved => 'Perfil guardado';

  @override
  String failedToSaveProfile(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get myCallPrice => 'Mi Precio de Llamada';

  @override
  String get spark => 'Chispa';

  @override
  String get youEarnSparks =>
      'Ganas Chispas cada segundo que estás en una llamada';

  @override
  String get fairPricingGetsMoreCalls =>
      'Los precios justos te dan más llamadas, más rápido';

  @override
  String get callersWillSee => 'Las personas que llamen verán:';

  @override
  String get videoCall => 'Videollamada';

  @override
  String get perMinute => '/min';

  @override
  String get chooseYourRate => 'Elige tu tarifa';

  @override
  String yourLevelIs(int level) {
    return 'Tu nivel es $level. Los niveles más altos se desbloquean en niveles mayores.';
  }

  @override
  String get tier => 'Nivel';

  @override
  String get youEarn => 'Ganas';

  @override
  String get callerPays => 'El que llama paga';

  @override
  String get callRateSaved => 'Tarifa de llamada guardada';

  @override
  String failedToSaveRate(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get lockedTiersUnlock =>
      'Los niveles bloqueados se desbloquean al subir de nivel siendo activo en Zephyr.';

  @override
  String videoCallWithRate(String rate) {
    return 'Videollamada $rate';
  }

  @override
  String get messageButton => 'Mensaje';

  @override
  String get notAvailable => 'No disponible';

  @override
  String get currentlyBusy => 'Ocupado ahora';

  @override
  String get followers => 'Seguidores';

  @override
  String get followButton => 'Seguir';

  @override
  String get followingButton => 'Siguiendo';

  @override
  String get about => 'Acerca de';

  @override
  String get noBioYet => 'Sin biografía aún.';

  @override
  String get gifts => 'Regalos';

  @override
  String get noGiftsYet => 'Sin regalos aún.';

  @override
  String get getReady => '¡Prepárate!';

  @override
  String get startingYourStream => 'Iniciando tu transmisión…';

  @override
  String get cancel => 'Cancelar';

  @override
  String get liveIndicator => 'EN VIVO';

  @override
  String get endLive => '¿Terminar en vivo?';

  @override
  String get streamWillEndMessage =>
      'Tu transmisión terminará y los espectadores serán desconectados.';

  @override
  String get endLiveButton => 'Terminar';

  @override
  String get startingCamera => 'Iniciando cámara…';

  @override
  String get cameraIsOff => 'Cámara apagada';

  @override
  String get micOn => 'Micrófono encendido';

  @override
  String get micOff => 'Micrófono apagado';

  @override
  String get camera => 'Cámara';

  @override
  String get off => 'Apagado';

  @override
  String get flip => 'Voltear';

  @override
  String totalWatching(int total) {
    return '$total viendo';
  }

  @override
  String get noViewersYet => 'Sin espectadores aún';

  @override
  String andMoreWatching(int count) {
    return 'y $count más viendo…';
  }

  @override
  String get saySomething => 'Di algo…';

  @override
  String get welcomeToLive => '¡Bienvenido a mi en vivo! 👋';
}
