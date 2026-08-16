# GMod Atmos — использованные материалы и адаптация

Источник: предоставленный владельцем архив `Gmod Atmos.zip`, Atmos v1.92, исторический Workshop ID `185609021`.

GRM **не подключает старое ядро Atmos целиком**. В частности, не перенесены:

- `engine.LightStyle`/`light_environment FadeToPattern` для цикла суток;
- `render.RedownloadAllLightmaps`;
- глобальная подмена `game.CleanUpMap`;
- старые net receivers и spawnmenu-конфигурация;
- глобалы `AtmosStorming`/`AtmosSnowing`.

Из архива аккуратно адаптированы:

- loop-cued `sound/atmos/rain.wav`;
- пять вариантов грома в `sound/atmos/thunder/`;
- материалы капли, дождевого тумана, брызги и снега в `materials/atmos/`;
- принцип проверки открытого неба;
- коллизии капель с локальной брызгой;
- движение `env_sun` и фазовые параметры SkyPaint.

GRM-реализация использует собственные Persistence, Net Guard, Audit, меню, серверные часы и lifecycle. Проверки неба кешируются по сетке, плотность частиц ограничена, а скомпилированные lightmaps карты не изменяются.
