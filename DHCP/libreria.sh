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
		sed -i 's/INTERFACESv4="/&'$interfaz'/' /etc/default/isc-dhcp-server
	fi
}
