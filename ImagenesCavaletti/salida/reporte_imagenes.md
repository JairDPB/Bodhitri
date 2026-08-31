# Imagenes Cavaletti - seleccion final para Business Central

- Referencias en el portafolio: **72**
- Referencias con imagen en el ZIP: **71**
- Referencias sin imagen: **1** -> `M2620500101009`
- Origen elegido: **71** en-celda (alta resolucion), **0** flotantes
- ZIP: `C:\Users\jaduj\Documents\GitHub\Bodhitri\ImagenesCavaletti\salida\imagenes_cavaletti.zip` — 71 PNG en la raiz, sin carpetas, 3.07 MB

## Como se verifico el mapeo

El encargo pedia contrastar los dos metodos entre si. Conviene decir primero una cosa: **ese contraste, por si solo, seria circular**. El mapa en-celda no se leyo del formato (la cadena `richValue` esta rota en este archivo: no hay `xl/metadata.xml` ni `rdrichvalue.xml`, y ninguna celda lleva `vm=`), sino que se reconstruyo emparejando cada imagen de `richData` con su gemela flotante por parecido. Comprobar despues que ambas se parecen solo repite esa construccion.

Por eso la verificacion se apoya en **tres patas, dos de ellas independientes de los pixeles**:

**1. Re-derivacion del anclaje (independiente).** Se reconstruyo el mapa referencia -> imagen flotante leyendo el `.xlsx` desde cero (`workbook.xml` -> rels de hoja -> `drawingN.xml` -> rels del drawing), sin usar los JSON previos. Resultado: **0 diferencias** en las 71 referencias, 72 referencias unicas y la misma unica sin anclaje. Este es el eslabon que de verdad ata una foto a un codigo, y esta confirmado por dos implementaciones.

**2. Regla de nombre de parte (independiente de los pixeles).** Las 79 imagenes de `richData` se llaman como su gemela flotante mas un digito (`image74.png` -> `image740.png`). Las 79 se reducen asi a una flotante existente. En **65** casos el nombre es inequivoco; de las 71 referencias de producto, **58** caen en ese grupo y el nombre coincide con el emparejamiento perceptual en **58 de 58, sin una sola discrepancia**.

**3. Maximo mutuo sobre la matriz completa (perceptual).** Correlacion en color sobre las **79x79** combinaciones -incluidas las 8 fotos de ambiente como competidoras-, exigiendo que la pareja asignada sea la mejor en *ambas* direcciones, no solo mirando la diagonal.

| Criterio | Referencias |
|---|---|
| Confirmadas por nombre **y** por maximo mutuo | 54 |
| Solo por regla de nombre | 4 |
| Solo por maximo mutuo | 13 |
| **Sin confirmar por ningun criterio** | **0** |

Las 13 referencias que la regla de nombre no fija (los nombres `imageN0` / `imageN1` en disputa) son **maximo mutuo las 13**, con margenes de +0,024 a +0,425 sobre la segunda candidata. Las 4 que no son maximo mutuo quedan fijadas por la regla de nombre. **Ninguna referencia se queda sin confirmar.**

Ademas, los 142 PNG extraidos son **identicos byte a byte** (MD5) a las partes originales del `.xlsx`, que se abrio siempre en solo lectura.

## Discrepancias

**Ninguna.** Las 71 referencias apuntan al mismo producto por los dos metodos.

Cuatro parejas no son maximo mutuo y se revisaron **una a una contra la descripcion del producto**; las cuatro resultaron correctas. La correlacion baja no viene de un error de mapeo sino de la geometria: son sillas y butacos de estructura metalica fina sobre fondo blanco, donde casi todo el encuadre es blanco y el parecido lo domina el antialiasing, distinto en cada resolucion.

| Referencia | corr | Rival | Veredicto tras inspeccion visual |
|---|---|---|---|
| M46020P00000A4 | 0,869 | M46060P00000A4 | Correcta: butaco todo plastico blanco, coincide con *ESPALDAR Y ASIENTO PLASTICO* |
| M46060P00000A4 | 0,886 | M46020P00000A4 | Correcta: espaldar blanco + sobreasiento rosa, coincide con *SOBREASIENTO TAPIZADO* |
| M46266N00000L1 | 0,927 | M46206N00000L1 | Correcta: espaldar blanco + asiento rosa, coincide con *ASIENTO TAPIZADO* |
| M4875200000001 | 0,999 | M4835200000001 | Ambas comparten foto (ver abajo); el criterio de maximo no aplica |

## Duplicadas perceptuales

Productos distintos que comparten la misma foto (correlacion > 0.97):

| Referencias | Correlacion | Lectura |
|---|---|---|
| M4835200000001 / M4875200000001 | 0.99965 | **Error del libro origen.** Segun descripcion son *PUFF REDONDO H35cm* y *H75cm*, pero ambas filas llevan la misma foto del puff alto. El puff de H45cm si aparece bajo, asi que la foto de M4835200000001 (H35) es casi seguro la equivocada |
| SFBD2P31126TPSB / SFBD2P31127TPBR | 0,97481 | Fotos distintas de productos muy parecidos: sofa 2P sin brazos y con *BRAZOS FIJOS*. No es un duplicado real |
| M46406O00027L1 / M46466O00027L1 | 0,97380 | Fotos distintas: asiento plastico vs *ASIENTO TAPIZADO*. No es un duplicado real |

El caso de control M4835200000001 / M4875200000001 **se detecta** (correlacion 0.99965, el par mas parecido de todo el catalogo) sin tocar el umbral sugerido de 0,97.

Pares mas parecidos, por si se quiere bajar el umbral:

| Referencias | Correlacion |
|---|---|
| M4835200000001 / M4875200000001 | 0.99965 |
| SFBD2P31126TPSB / SFBD2P31127TPBR | 0.97481 |
| M46406O00027L1 / M46466O00027L1 | 0.97380 |
| M46077A00000A4 / M46977A00027A4 | 0.95976 |
| M46976P00027A4 / M46977A00027A4 | 0.95404 |
| M46076P00000A4 / M46077A00000A4 | 0.94843 |
| SFBD2P31127TPBR / SFBD2P31128TRBJ | 0.94756 |
| M46206N00000L1 / M46266N00000L1 | 0.93861 |

## Resolucion

Medida sobre el **bounding box del producto** tras recortar el fondo blanco, no sobre el lienzo del archivo.

- Lado largo del producto: min **111** px / mediana **179** px / max **422** px
- La version en-celda aporta de media **3.4x** mas area util que la flotante (max 10.0x)

### Las 10 de peor resolucion efectiva

| # | Referencia | Hoja | Producto (px) | Lienzo (px) | Origen |
|---|---|---|---|---|---|
| 1 | SFBD1P31115TNBJ | BOLDY | 111x67 | 201x138 | encelda |
| 2 | M5210600000001482 | INAUT | 111x79 | 171x156 | encelda |
| 3 | M5200600000001481 | INAUT | 114x92 | 157x148 | encelda |
| 4 | M46067A00000A4 | MATCH | 99x127 | 156x184 | encelda |
| 5 | M46007A00000A4 | MATCH | 100x126 | 148x182 | encelda |
| 6 | M46907A00027A4 | MATCH | 100x127 | 169x198 | encelda |
| 7 | M46967A00027A4 | MATCH | 100x127 | 194x186 | encelda |
| 8 | M46077A00000A4 | MATCH | 100x128 | 146x170 | encelda |
| 9 | M46977A00027A4 | MATCH | 100x128 | 173x182 | encelda |
| 10 | M46966P00027A4 | MATCH | 100x129 | 156x173 | encelda |

La peor se queda en **111 px** de lado largo y la mediana en **179 px**. Da para la miniatura y la ficha de producto en Business Central, pero no para ampliar: si en algun momento hace falta catalogo en condiciones, estas imagenes no lo sustituyen. El techo lo pone el propio libro de Excel, que no guarda nada mejor.

### Detalle completo

| Referencia | Hoja | Origen | Producto (px) | Area flot. | Area celda | corr pareja |
|---|---|---|---|---|---|---|
| M2620100000007 | BLOKS | encelda | 150x144 | 8280 | 21600 | 0.98439 |
| M2621100000003 | BLOKS | encelda | 179x129 | 9379 | 23091 | 0.99786 |
| M2621200000004 | BLOKS | encelda | 273x148 | 15996 | 40404 | 0.99976 |
| M2622100000005 | BLOKS | encelda | 218x142 | 13536 | 30956 | 0.99566 |
| M2622200000006 | BLOKS | encelda | 312x161 | 16468 | 50232 | 0.99967 |
| M2622700000008 | BLOKS | encelda | 278x154 | 13330 | 42812 | 0.99943 |
| M2623100000001 | BLOKS | encelda | 147x178 | 6734 | 26166 | 0.97522 |
| M2623200000002 | BLOKS | encelda | 245x192 | 12474 | 47040 | 0.99872 |
| APBD31181SUME | BOLDY | encelda | 271x282 | 10812 | 76422 | 0.97978 |
| BUBDY31151TM | BOLDY | encelda | 142x189 | 5896 | 26838 | 0.92364 |
| MBA31185SMEMROD | BOLDY | encelda | 328x292 | 15196 | 95776 | 0.98749 |
| PBDY31161TMNV | BOLDY | encelda | 100x260 | 5781 | 26000 | 0.99656 |
| PBDY31162TMNV | BOLDY | encelda | 100x316 | 5289 | 31600 | 0.99713 |
| PBDY31363PTMRNY | BOLDY | encelda | 184x387 | 7316 | 71208 | 0.99748 |
| PRB31105TP | BOLDY | encelda | 238x164 | 12878 | 39032 | 0.99235 |
| PRB31125TP | BOLDY | encelda | 372x169 | 18564 | 62868 | 0.98048 |
| SFBD1P31115TNBJ | BOLDY | encelda | 111x67 | 4806 | 7437 | 0.99618 |
| SFBD1P31116TPN | BOLDY | encelda | 285x274 | 15621 | 78090 | 0.99757 |
| SFBD1P31117TNBJ | BOLDY | encelda | 286x274 | 14036 | 78364 | 0.99664 |
| SFBD1P31118TRBJ | BOLDY | encelda | 297x275 | 19992 | 81675 | 0.99796 |
| SFBD2P31126TPSB | BOLDY | encelda | 372x250 | 27135 | 93000 | 0.99959 |
| SFBD2P31127TPBR | BOLDY | encelda | 374x250 | 24320 | 93500 | 0.99958 |
| SFBD2P31128TRBJ | BOLDY | encelda | 382x250 | 23560 | 95500 | 0.99695 |
| M2611000101001 | DOMOS | encelda | 335x267 | 17850 | 89445 | 0.99474 |
| M2611100101001 | DOMOS | encelda | 266x156 | 18025 | 41496 | 0.99965 |
| M360713SH00A01 | DUO | encelda | 110x146 | 9890 | 16060 | 0.99852 |
| M3607200088003 | DUO | encelda | 101x145 | 8814 | 14645 | 0.99690 |
| M3607400006001 | DUO | encelda | 100x147 | 8400 | 14700 | 0.97836 |
| M3617200007001 | DUO | encelda | 99x149 | 7704 | 14751 | 0.99857 |
| M3617400006001 | DUO | encelda | 106x145 | 9102 | 15370 | 0.99752 |
| M3627200007001 | DUO | encelda | 100x146 | 9360 | 14600 | 0.99824 |
| M5200600000001481 | INAUT | encelda | 114x92 | 6734 | 10488 | 0.99856 |
| M5210600000001482 | INAUT | encelda | 111x79 | 5696 | 8769 | 0.98488 |
| M46006P00000A4 | MATCH | encelda | 260x335 | 19557 | 87100 | 0.99581 |
| M46007A00000A4 | MATCH | encelda | 100x126 | 8160 | 12600 | 0.97955 |
| M46020P00000A4 | MATCH | encelda | 97x144 | 8970 | 13968 | 0.86926 |
| M46060P00000A4 | MATCH | encelda | 97x143 | 8855 | 13871 | 0.88592 |
| M46066P00000A4 | MATCH | encelda | 101x130 | 8320 | 13130 | 0.98686 |
| M46067A00000A4 | MATCH | encelda | 99x127 | 8080 | 12573 | 0.95318 |
| M46070P00000A4 | MATCH | encelda | 97x146 | 9126 | 14162 | 0.99057 |
| M46076P00000A4 | MATCH | encelda | 102x130 | 8528 | 13260 | 0.99407 |
| M46077A00000A4 | MATCH | encelda | 100x128 | 8160 | 12800 | 0.99830 |
| M46206N00000L1 | MATCH | encelda | 100x133 | 8560 | 13300 | 0.98601 |
| M46266N00000L1 | MATCH | encelda | 100x134 | 8532 | 13400 | 0.92714 |
| M46276N00000L1 | MATCH | encelda | 100x134 | 8532 | 13400 | 0.92585 |
| M46306M00000L1 | MATCH | encelda | 101x130 | 8505 | 13130 | 0.99836 |
| M46366M00000L1 | MATCH | encelda | 101x131 | 8424 | 13231 | 0.97553 |
| M46376M00000L1 | MATCH | encelda | 101x132 | 8586 | 13332 | 0.99778 |
| M46406O00027L1 | MATCH | encelda | 104x130 | 8446 | 13520 | 0.99257 |
| M46466O00027L1 | MATCH | encelda | 103x129 | 8632 | 13287 | 0.99449 |
| M46476O00027L1 | MATCH | encelda | 104x130 | 8715 | 13520 | 0.99813 |
| M46906P00027A4 | MATCH | encelda | 101x128 | 8343 | 12928 | 0.99324 |
| M46907A00027A4 | MATCH | encelda | 100x127 | 8080 | 12700 | 0.96641 |
| M46966P00027A4 | MATCH | encelda | 100x129 | 8343 | 12900 | 0.96509 |
| M46967A00027A4 | MATCH | encelda | 100x127 | 8160 | 12700 | 0.99555 |
| M46976P00027A4 | MATCH | encelda | 101x130 | 8424 | 13130 | 0.99896 |
| M46977A00027A4 | MATCH | encelda | 100x128 | 8240 | 12800 | 0.98469 |
| M4835100000001 | PIBOU | encelda | 197x168 | 8415 | 33096 | 0.99932 |
| M4835200000001 | PIBOU | encelda | 231x286 | 11760 | 66066 | 0.99911 |
| M4845100000001 | PIBOU | encelda | 193x191 | 10200 | 36863 | 0.98333 |
| M4845200000001 | PIBOU | encelda | 233x205 | 12051 | 47765 | 0.99893 |
| M4875100000001 | PIBOU | encelda | 269x290 | 7820 | 78010 | 0.97960 |
| M4875200000001 | PIBOU | encelda | 232x286 | 9701 | 66352 | 0.99853 |
| D3655500013002 | TALK | encelda | 339x336 | 12656 | 113904 | 0.99765 |
| D3656524013010 | TALK | encelda | 422x392 | 24776 | 165424 | 0.99963 |
| D3657524013009 | TALK | encelda | 373x297 | 15070 | 110781 | 0.98400 |
| M3650500013003 | TALK | encelda | 113x116 | 8372 | 13108 | 0.99603 |
| M3650500013012 | TALK | encelda | 286x299 | 11984 | 85514 | 0.99862 |
| M3650500013024 | TALK | encelda | 289x298 | 11988 | 86122 | 0.99922 |
| M3650500013036 | TALK | encelda | 283x204 | 10353 | 57732 | 0.99712 |
| MO1180102 | TALK | encelda | 174x237 | 6650 | 41238 | 0.99627 |
