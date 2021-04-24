#! /bin/env bash
. ./libreria.sh

#Este script configura las cuotas en un dispositivo de bloques que se encuentre
#en tu equipo. Para ello debes saber el directorio en el que quieres aplicar
#las cuotas y el nombre del dispositivo. El nombre del dispositivo se dará
#en formato /dev/nombre. Dicho dispositivo debe estar particionado y con 
#un sistema de ficheros instalado o el script no funcionará.

#El script empieza comprobando si eres root. Si no lo eres, te echa del script
#avisándote de que no eres root.
f_soyroot

#Después usa la función f_comprobar_paquete para saber si tienes instalado los
#paquetes quota y quotatool, si no es así, te pregunta si quieres instalarlo.
paquete=quota
paquete2=quotatool
f_comprobar_paquete $paquete
f_comprobar_paquete $paquete2

#A continuación usa la función f_UUID para obtener el UUID del dispositivo de
#bloques que tienes montado en el directorio en el que quieres instaurar las
#cuotas. Si todo va bien, te pregunta el directorio y el nombre del dispositivo.
echo "Dime el punto de montaje del dispositivo"
read directorio
echo "Dime el nombre del dispositivo"
read nombre
f_comprobacion_inicial
f_UUID

#Tras esto, vamos a usar el UUID obtenido para modificar el fichero fstab. Si el
#dispositivo de bloques no está incluido en fstab, el script te lo incluye.

f_modificar_fstab_quota

#Ahora comprobaremos si ya dispones de los ficheros de configuración, y si no es así
#los crearemos

echo "Comprobando ficheros de configuración"
f_habilita_quota


#Ahora crearemos el usuario que vamos a usar como base para copiar la plantilla de cuotas
f_creacion_usuario
echo "Usuarios creados"

#Ahora configuraremos las cuotas de los usuarios usando como plantilla las cuotas que 
#impongamos al usuario debian1, que habremos creado con la función anterior.
f_configurar_cuotas


#Una vez configuradas las cuotas de debian1, usaremos las mismas cuotas para el resto de 
#usuarios con un UUID mayor al suyo.
f_plantilla_cuota
echo "Cuotas configuradas con éxito"
echo "Fin del script"
