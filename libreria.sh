

#Primero vamos a comprobar si existe el directorio /QUOTA. Esta función
#llama a una variable que será especificida por el script , y devolverá 1 si no existe y 0 si existe.

function f_existe_directorio {
		if [[ -d $directorio ]]
			then
				return 0
		else
			return 1
		fi

}

#La siguiente función creará el direcotorio donde se montará el dispositivo
#si no está creado ya.

function f_crear_directorio {
	mkdir $directorio
}

#La siguiente función montará el dispositivo si no está montado ya. Para ello
#preguntará al usuario el nombre del dispositivo de bloques a montar

function f_montar_dispositivo {
	mount $nombre $directorio
}


#La siguiente función usa a la anterior para comprobar si existe un directorio o no, y si 
#no es así crearlo. También comprueba si el dispositivo está montado, y si no es así lo monta.

function f_comprobacion_inicial {
	f_existe_directorio
	resul=`echo $?`
	if [[ $resul = 1 ]]; then
		f_crear_directorio		
	fi
	if [[ $(df -h | egrep $nombre;echo $?) = 1 ]]; then
		f_montar_dispositivo
	fi
}
#Para poder continuar, es necesario ser root, por lo que la siguiente función
#nos indicará si eres root. Si es así, te permitirá continuar y debolverá 0. 
#En cambio si no lo eres, te echará del script, devolviendo 1.

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

#Esta función obtiene el UUID del dispositivo montado en el directorio que que recibe. Si el
#directorio no existe o no hay nada montado en él, llama a otra función para indicarte
#cual es el problema.

function f_UUID {
	UUID=$(blkid -o value -s UUID $nombre)
	if [[ -z $UUID ]]
		then
			echo "Dime el nombre del dispositivo a montar"
			f_nombre_dispositivo
	else
		echo $UUID

	fi
}

#Esta función instala el paquete que le añadas como argumento. Primero comprueba
#si eres root y despues instala el paquete.

function f_instalar_paquete {
	apt update -y &> /dev/null && apt install -y $1 &> /dev/null
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

#Esta función añade al fichero fstab el dispositivo de bloques al que vamos a implantar las cuotas.
#Para eelo utiliza el comando echo y una doble redirección para anexar al final del archivo la línea
#correspondiente al dispositivo de bloques, con las opciones de cuotas ya añadidas.

function f_anadir_fstab {
	UUID=$(f_UUID)
	formato=$(lsblk -f | egrep $UUID | awk '{print $2}') 
	echo "UUID=$UUID $directorio $formato defaults,usrquota,grpquota 0 1" >> /etc/fstab
}


#Esta función usa la función f_UUID para obtener la UUID de un determinado dispositivo montado
#en un directorio. Hay que ser root para ello. Tras esto usa la variable obtenida con el comando 
#sed para crear un fichero, modificarlo y después inyectárlo a un fichero fstab temporal.
#Posteriormente se combinan los dos ficheros, se elimina el fichero antiguo y se cambia el 
#nombre al temporal para que actúe como el nuevo. Tras esto vuelve a leer el fichro fstab. Si el
#dispositivo no está incluido en el fichero fstab, lo incluye usando la función anterior.

function f_modificar_fstab_quota {
	UUID=$(f_UUID)
	if [[ $(egrep $UUID /etc/fstab;echo $?) = 1 ]]; then
		f_anadir_fstab
	else
		sed -e '/'$UUID'/ !d' /etc/fstab > uuid.txt
		opciones=$(sed -e '/'$UUID'/ !d' /etc/fstab | awk '{print $4}')
		sed -i 's/'$opciones'/&,usrquota,grpquota/' uuid.txt
		sed -e '/'$UUID'/ d' /etc/fstab > fstab1
		cat uuid.txt >> fstab1
		rm /etc/fstab uuid.txt
		mv fstab1 /etc/fstab
	fi
	mount -o remount $directorio &> /dev/null
}


#Con esta función comprobamos si los ficheros de quotas están en el directorio donde hemos montado 
#las cuotas. Te informa de si están creados los ficheros de usuario,grupo o ninguno. Devuelve 1 si está
#creado el fichero de grupo,2 si está creado el de usuario,0 si no está creado ninguno y 3 si están
#creados los dos.

function f_comprobar_fichero_quota {
	set $(ls $directorio)
	contador=1
	vueltas=$#
	for i in $(seq 1 $vueltas)
		do
			if [[ $1 = "aquota.group" ]];then
				((contador++))
				num1=1
				shift 1;
			elif [[ $1 = "aquota.user" ]];then
				((contador++))
				num2=2
				shift 1;
			else
				shift 1;
			fi
		done;
	if [[ $contador = 1 ]]; then
		num3=0
	fi
	if [[ $num3 = 0 ]];then
		return 0
	else
		if [[ -z $num1 && -n $num2 ]];then
			return 2
		elif [[ -z $num2 && -n $num1 ]];then
			return 1
		else
			return 3
		fi
	fi
}


#Con esta función crearemos los ficheros necesarios para trabajar con las cuotas: aquota.user y #aquota.group. Primero usaremos la función la función anterior para averiguar si ya existen, y si #no es así crearlos. Tras esto habilitaremos las cuotas con el comando quotaon.
#Usa el comando anterior para saber si los ficheros ya existen.

function f_habilita_quota {
	f_comprobar_fichero_quota
	if [[ $? = 1 ]]; then
		quotacheck -u $directorio &> /dev/null
	elif [[ $(f_comprobar_fichero_quota;echo $?) = 2 ]]; then
		quotacheck -g $directorio &> /dev/null
	elif [[ $(f_comprobar_fichero_quota;echo $?) = 0 ]]; then
		quotacheck -ugv	$directorio &> /dev/null
	else
		echo "Los ficheros ya están creados"
	fi
	quotaon $directorio &> /dev/null
}

#Con esta función crearemos el número de usuarios que queramos, cada uno con su directorio 
#personal. No los crea con contraseñas, por lo que solo el root puede acceder a ellos hasta
#que se les ponga contraseña.


function f_creacion_usuario {
	echo "¿Cuántos usuarios quieres crear?"
	read numusuario
	for i in $(seq 1 $numusuario)
		do 
			useradd -m -s /bin/bash debian$i;
		done
}

#Con esta función aplicamos unas cuotas básicas al usuario creado con la función anterior.
#Solo se lo aplica al primero creado, ya que serán sus cuotas las que usaremos como plantillas
#para asignar al resto de usuarios. Por el reducido almacenamiento de que disponemos,
#usaremos megas para referirnos a los bloques, aunque esto puede ser modificado más adelante.


function f_configurar_cuotas {
	echo "¿El límite será de inodos o bloques?(i/b)"
	read  limite
	if [[ $limite = 'b' ]];then
		echo "Dígame el límite blando en megas"
		read b_limite
		echo "Dígame el límite duro en megas"
		read d_limite
		quotatool -u debian1 -b -q $b_limite\M -l $d_limite\M $directorio
	else
		echo "Dígame el límite blando de inodos"
		read b_limite
		echo "Dígame el límite duro de inodos"
		read d_limite
		quotatool -u debian1 -i -q $b_limite -l $d_limite $directorio
	fi
}


#Con esta función usaremos las cuotas aplicadas al usuario de la función anterior como
#plantilla para aplicar las mismas a todos los usurios con un UUID mayor al del usuario base. 

function f_plantilla_cuota {
	usuario_uuid=$(cat /etc/passwd | egrep 'debian1' | awk -F : '{print $3}')
	edquota -p debian1 `awk -F : '$3 > '$usuario_uuid' {print $1}' /etc/passwd`
	quotaon $directorio &> /dev/null
}

