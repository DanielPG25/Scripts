#Esta función determina si eres root o no usando el comando whoami. Si lo 
#eres devuelve 0, si no es así te echa del script, ya que no tendría sentido continuar.


function f_soyroot {
	set $(whoami)
	if [[ $1 = 'root' ]]
		then
			return 0
	else
		echo "No eres root"
		exit 1
	fi
}


#Esta función necesita de un argumento. Le pasas el nombre del paquete, y si 
#está instalado te lo indica. Si no es así te pregunta si quieres instalarlo.
#Para instalar el paquete debes ser root.

function f_comprobar_paquete {
	if [[ $(dpkg -s $1) ]]
		then
			return 0
	else
		echo "El paquete no está instalado, ¿quieres instalarlo?(s/n)"
		read confirmacion
		if [[ $confirmacion = "s" ]]; then
			f_instalar_paquete $1
		else
			exit 1
		fi
	fi
}



#Esta función instala el paquete que le añadas como argumento. Solo instala un paquete,
#aunque dependiendo de la situación podría modificarse para que instalase varios


function f_instalar_paquete {
	apt update -y &> /dev/null && apt install -y $1 &> /dev/null
}

#Esta función muestra las interfaces para que el usuario pueda elegir una a la que 
#aplicar el servidor dhcp. No requiere de argumentos de entrada.

function f_mostrar_interfaces {
	ip link show | awk 'NR % 2 == 1' | awk '{print $2}' | tr -d ':'
}

#La siguiente función comprueba si la interfaz dada a través de un argumento existe o no. Devolverá 0
#si existe u otro número si no existe.


function f_comprobar_interfaz {
	ip link show | awk 'NR % 2 == 1' | awk '{print $2}' | tr -d ':' | egrep $interfaz > /dev/null
}


#Esta función detecta si la interfaz que has elegido está levantada o no, e informa al usuario.
#Si no lo está le pregunta al usuario si quiere levantarla, si este responde que no, el script 
#se acaba.

function f_levantar_interfaz {
	if [[ $(ip link show | egrep $interfaz | egrep -i 'state down' > /dev/null;echo $?) = 0 ]]; then
		echo "La interfaz $interfaz está bajada. ¿Levantárla? (s/n)"
		read confirmacion
		if [[ $confirmacion = 's' ]]; then
			ip link set $interfaz up
			echo "Interfaz levantada"
		else
			exit 1
		fi
	fi
}


#Esta función se utiliza para modificar el archivo /etc/default/isc-dhcp-server, insertándo
#la interfaz a la que vamos a aplicar el servidor dhcp. Primero revisa si ya está configurado,
#y si no es así, lo configura.

function f_modificar_isc-dhcp-server {
	if [[ $(cat /etc/default/isc-dhcp-server | egrep -i "INTERFACESv4" | egrep $interfaz > /dev/null;echo $?) != 0 ]]; then
		sed -i 's/INTERFACESv4="/&'$interfaz' /' /etc/default/isc-dhcp-server
	fi
}



function f_modificar_configuracion_global {
	if [[ $(cat /etc/dhcp/dhcpd.conf | egrep -o "#authoritative" > /dev/null;echo $?) = 0 ]]; then
		echo "Este servidor dhcp no esta funcionando como servidor principal de la red"
		echo "No es obligatorio que sea principal para que funcione correctamente"
		echo "¿Deseas hacerlo principal?(s/n)"
		read confirmacion
		if [[ $confirmacion = "s" ]];then
			sed -i 's/#authoritative/authoritative/' /etc/dhcp/dhcpd.conf
		fi
	fi
	echo "La configuración global de dns es la siguiente:"
	cat /etc/dhcp/dhcpd.conf | egrep -m 2 "option domain-name"
	echo "¿Desea cambiarla?(s/n)"
	read confirmacion
	if [[ $confirmacion = "s" ]];then
		sed -i '/^option domain-name /d' /etc/dhcp/dhcpd.conf 
		sed -i '/^option domain-name-servers /d' /etc/dhcp/dhcpd.conf 
		echo "¿Qué nombre de dominio quiere meter en la configuración?"
		read dom1
		sed -i '/# option definitions/ a option domain-name "'$dom1'";' /etc/dhcp/dhcpd.conf
		sed -i '/# option definitions/ a option domain-name-servers ;' /etc/dhcp/dhcpd.conf
		echo "¿Cuántos servidores de nombres de dominio quieres meter en la configuración?"
		read num1
		for i in $(seq 1 $num1)
			do
				echo "Dime el nombre del servidor $i"
				read serv
				sed -i 's/^option domain-name-servers /&'"$serv"' /' /etc/dhcp/dhcpd.conf
			done;
	fi
}
