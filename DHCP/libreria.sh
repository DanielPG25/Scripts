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

#Esta función modifica la configuración global del dns que otorga el servidor dhcp si no se pone una 
#específica para la subred. Primero muestra la configuración que hay ya, y después pregunta al usuario si
#desea cambiarla. Si es así, pregunta al usuario por cada uno de los parámetros y los configura según
#lo que el usuario introduzca por teclado. También revisa si el servidor no está marcado como principal en
#la red, y si no es así, pregunta al usuario si quiere que lo sea.

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
				if [[ $i = 1 ]]; then
					sed -i 's/^option domain-name-servers /&'"$serv"' /' /etc/dhcp/dhcpd.conf
				else
					sed -i 's/^option domain-name-servers /&'"$serv"', /' /etc/dhcp/dhcpd.conf
				fi
			done;
	fi
}


#Con la siguiente función vamos a revisar el fichero /etc/dhcp/dhcpd.conf 
#para comprobar si ya tiene una subnet creada. En caso positivo, se le muestra al
#usuario la configuración de la subnet, y se le pregunta si desea continuar con
#el script o si desea continuar con la configuración que ya tiene.

function f_comprobar_subnet {
	if [[ $(cat /etc/dhcp/dhcpd.conf | awk '/^subnet/,/\}$/' | egrep subnet > /dev/null;echo $?) = 0 ]]; then
		echo "Ya tiene creada la siguiente subnet: "
		cat /etc/dhcp/dhcpd.conf | awk '/^subnet/,/\}$/'
		echo "¿Desea iniciar el servidor con  esta configuración? (s/n)"
		read respuesta
		if [[ $respuesta = 's' ]]; then
			echo "De acuerdo, iniciemos el servidor"
			return 1
		else
			echo "De acuerdo, crearemos otra subred"
			return 0
		fi
	fi
}


#Con la siguiente función vamos a modificar el fichero /etc/dhcp/dhcpd.conf 
#para insertar la configuración de la subnet que daremos por dhcp y sus opciones
#Para ello iremos preguntando al usuario por cada una de las opciones y las iremos 
#anexando una a una.

function f_anadir_subnet {
	echo "Digame la subnet en notación decimal puntuada (ejemplo: 192.168.0.0):"
	read ip
	echo "Dígame la mascara de red en notación decimal puntuada: (ejemplo: 255.255.255.0):"
	read mascara
	echo "subnet $ip netmask $mascara {" > axklmldhcp.txt
	echo "Empecemos a configurar la subnet. Dígame el rango inferior de ip que va a repartir el servidor"
        read inferior
        echo "Ahora dígame el límite superior de ip que va a repartir el servidor: "
        read superior
        sed -i '$a \  range '$inferior' '$superior';' axklmldhcp.txt
	echo "A partir de ahora configuraremos parámetros que son importantes, pero son opcionales, así que no es necesario ponerlos para el funcionamiento del servidor"
        echo "¿Desea configurar la puerta de enlace? (s/n)"
        read respuesta
        if [[ $respuesta = "s" ]];then
                echo "Dígame la dirección de la puerta de enlace (ej: 192.168.0.1):"
                read puerta
                sed -i '$a \  option routers '$puerta';' axklmldhcp.txt
        else
                echo "De acuerdo"
        fi
	echo "¿Desea configurar la mascara de red que otorgará el servidor? (s/n)"
	read respuesta
	if [[ $respuesta = "s" ]];then
		echo "Dígame la mascara de red que otorgará el servidor dhcp (ej: 255.255.255.0):"
		read submascara
		sed -i '$a \  option subnet-mask '$submascara';' axklmldhcp.txt
	else
		echo "De acuerdo"
	fi
	echo "¿Desea configurar la búsqueda de dominios? (s/n)"
	read respuesta
	if [[ $respuesta = "s" ]];then
		echo "¿Qué nombre de dominio desea introducir en la configuración?"
		read dominio
		sed -i '$a \  option domain-search \"'$dominio'\";' axklmldhcp.txt
	else
		echo "De acuerdo"
	fi
	echo "¿Desea configurar los sevidores de nombres de dominio? (s/n)"
	read respuesta
	if [[ $respuesta = "s" ]];then
		sed -i '$a \  option domain-name-servers ;' axklmldhcp.txt
		echo "¿Cuántos servidores de nombres de dominio quieres meter en la configuración?"
                read num1
                for i in $(seq 1 $num1)
			do
                                echo "Dime el nombre del servidor $i"
                                read serv
                                if [[ $i = 1 ]]; then
                                        sed -i 's/option domain-name-servers /&'"$serv"' /' axklmldhcp.txt
                                else
                                        sed -i 's/option domain-name-servers /&'"$serv"', /' axklmldhcp.txt
                                fi
                        done;

	else
		echo "De acuerdo"
	fi
	echo "¿Desea introducir una dirección de broadcast? (s/n)"
	read respuesta
	if [[ $respuesta = "s" ]];then
		echo "Introduzca la dirección de broadcast (ej: 192.168.0.255):"
		read broadcast
		sed -i '$a \  option broadcast-address '$broadcast';' axklmldhcp.txt
	else
		echo "De acuerdo"
	fi
	echo "¿Cuál será el tiempo de préstamo (lease time) por defecto de la subred (en segundos)?"
	read deflease
	sed -i '$a \  default-lease-time '$deflease';' axklmldhcp.txt
	echo "¿Cuál será el tiempo de préstamo máximo de la subred (en segundos)?"
	read maxlease
	sed -i '$a \  max-lease-time '$maxlease';' axklmldhcp.txt
	sed -i '$a \}' axklmldhcp.txt
	echo "Subred configurada"
}
