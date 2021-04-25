#! /bin/env bash
. ./libreria.sh


#El objetivo de este script es instalar y configurar un servidor dhcp plenamente
#operativo en un sistema operativo Debian 10. Solo se ha probado en este sistema,
#por lo que no puedo asegurar su correcto funcionamiento en otros sistemas operativos
#u otras versiones de debian.


#Para empezar es necesario ser root para ejjecutar la mayoría de instrucciones de este
#script, por lo que la siguiente función se asegurará de ello.

#f_soyroot

#A continuación, debemos asegurarnos que el paquete necesario "isc-dhcp-server", esta instalado,
#y si no es así instalarlo. Se le dará opción al usuario de no instalarlo si no quiere,
#pero si no quieres instalarlo se le echará del script, puesto no que no tendría sentido continuar.

#paquete=isc-dhcp-server
#f_comprobar_paquete $paquete

#Ahora vemos a mostrar por pantalla las interfaces que tenemos disponibles, para que el 
#usuario pueda elegir a la que quiera aplicar el servidor dhcp. Si el usuario se equivoca
#al escribir la interfaz o la interfaz no existe, te vuelve a pregutar hasta que elijas una
#que exista

echo "De las siguientes interafaces, escribe el nombre de a la que le quieras aplicar el servidor dhcp:"
echo ""
f_mostrar_interfaces
echo ""
read interfaz

while [[ $(f_comprobar_interfaz $interfaz;echo $?) != 0 ]]
	do
		echo "Esa interfaz no existe"
		echo "Compruebe la sintaxis e introduzca de nuevo la interfaz"
		read interfaz
	done

#Lo siguiente es comprobar si la interfaz elegida está levantada o bajada. Para ello usaremos 
#la siguiente función.

f_levantar_interfaz
