
# Autores:
## Eva Maria Arce Ale
## Diego García López
## David Sineiro Barreiro
## Adrián López Gude
## Alejandro Rodríguez Vaquero
# Curso: 2022-2023
# Práctica 3


## Objetivo:
   Esta práctica consiste en proponer, diseñar, implementar y presentar un sistema de arquitecturas
   mediante el lenguaje Elixir. También se detallará en este README la descripción de los requisitos
   funcionales y no funcionales.
   Las arquitecturas escogidas para esta práctica son la arquitectura Peer-to-Peer y la arquitectura líder-trabajador.

## Descripción:
   Este programa consta de 2 arquitecturas:
   Con la arquitectura P2P se simula una base de datos distribuída entre diferentes peers que se comunican formando un
   anillo. De esta manera, puedes comunicarte con cualquiera de los peers para enviar, solicitar o borrar cualquier
   archivo de la arquitectura. Cada uno de estos peers cuentan con, de manera interna, una arquitectura líder-trabajador.

   Con la arquitectura líder-trabajador buscamos permitir el cifrado y descifrado de varios archivos simultáneamente.
   De esta manera, conseguimos que el peer no se quede bloqueado cuando deba almacenar o devolver un archivo.



## Requisitos funcionales:

### Envío de ficheros
   El usuario puede comunicarse con cualquiera de los peers a través de su API mediante la llamada 'send_file(peer,file)',
   donde 'peer' es el nombre que recibe el peer dentro de su anillo o una tupla conformada por el átomo global seguido del
   nombre del nodo que contiene el anillo, que permite acceder al peer inicial de dicho anillo: {:global, :"a@PC"}.
   El argumento 'file' contiene el nombre del archivo que se quiere guardar.

### Recuperación de ficheros
   El usuario puede comunicarse con cualquiera de los peers a través de su API mediante la llamada 'get_file(peer,file)',
   donde 'peer' es el nombre que recibe el peer dentro de su anillo o una tupla conformada por el átomo global seguido del
   nombre del nodo que contiene el anillo, que permite acceder al peer inicial de dicho anillo: {:global, :"a@PC"}.
   El argumento 'file' contiene el nombre del archivo que se quiere recuperar.

### Borrado de ficheros
   El usuario puede comunicarse con cualquiera de los peers a través de su API mediante la llamada 'delete_file(peer,file)',
   donde 'peer' es el nombre que recibe el peer dentro de su anillo o una tupla conformada por el átomo global seguido del
   nombre del nodo que contiene el anillo, que permite acceder al peer inicial de dicho anillo: {:global, :"a@PC"}.
   El argumento 'file' contiene el nombre del archivo que se quiere borrar.
   La instrucción 'delete_file()' borra la primera aparición del fichero en el anillo, pero también existe la llamada 
   'delete_all()' que permite borrar todas las apariciones de dicho fichero.

### Cifrado de ficheros
   Gracias a la implementación de un módulo llamado "Cloak.Vault" podremos usar las funciones 'encrypt()' y 'decrypt()' de
   dicho módulo para encriptar y desencriptar respectivamente mediante un algoritmo de cifrado AES.



## Requisitos no funcionales:

### Disponibilidad
   La disponibilidad se consigue gracias a la existencia de varios peers, lo cual permite que se distribuya la carga de
   trabajo dentro del anillo. Así mismo, la existencia de una arquitectura líder-trabajador dentro de cada peer que trabaja
   de manera asíncrona permitirá evitar el bloqueo del peer ante cada una de las llamadas.

### Rendimiento
   El rendimiento de nuestro sistema se consigue mediante la arquitectura líder-trabajador, que permite que ninguna llamada esté
   esperando para ser ejecutada.





## Contenido de archivos importantes:

### /doc/C4.pdf
   Contiene un pdf con los diagramas C4.

### /lib/cryptolider.ex
   Contiene la implementación del módulo lider de la arquitectura lider-trabajador donde permitiremos
   cifrar y guardar archivos. Posee un pool de procesos trabajadores que van recibiendo las peticiones,
   así como la capacidad de crear y destruir dichos trabajadores para manejar correctamente el número
   de peticiones que recibe. Implementa GenServer.

### /lib/cryptopeer.ex
   Contiene la implementación de una arquitectura P2P para administrar las peticiones para buscar, almacenar
   o enviar ficheros. Implementa GenServer y posee un proceso hijo que se caracteriza por ser el líder de una
   arquitectura líde-trabajador.

### /lib/cryptovault.ex
   Contiene un módulo con la implementación de encriptado. Posee la configuración necesaria para poder
   cifrar y descifrar archivos.

### /lib/cryptoworker.ex
   Contiene la implementación del trabajador de esta arquitectura que se caracteriza por permitir el
   cifrado y descifrado de archivos



## Como Ejecutar + comandos importantes: 

### Comandos de compilación y ejecución del programa:
#### mix compile
Compila los archivos.

#### mix deps.get
Crea dependencias.

#### iex -S mix
Con este comando podremos poner en funcionamiento el programa.


### Comandos del programa (después de iex -S mix)

#### Cryptopeer.send_file("peer0","prueba.txt")
Guarda el archivo "prueba.txt" en el peer0. En el caso de que peer0 esté lleno, se reenviará al siguiente peer.
Esta llamada se puede hacer sobre los demás peers (peer1, peer2 y peer3).

#### Cryptopeer.send_file({:global,:"a@PC"},"prueba.txt")
Guarda el archivo "prueba.txt" en el peer0 del nodo a@PC. En el caso de que peer0 esté lleno, se reenviará al siguiente peer.

#### Cryptopeer.get_file("peer0","prueba.txt")
Solicita el archivo "prueba.txt" al peer0. Si el archivo está en este anillo o en alguno conectado a él se devuelve.
Esta llamada se puede hacer sobre los demás peers (peer1, peer2 y peer3).

#### Cryptopeer.get_file({:global,:"a@PC"},"prueba.txt")
Solicita el archivo "prueba.txt" en el peer0 del nodo a@PC.

#### Cryptopeer.list_files()
Permite mostrar por pantalla una lista de los archivos almacenados en los peers del anillo.

#### Cryptopeer.delete_file("peer0","prueba.txt")
Permite borrar la primera aparición del fichero especificado en el anillo empezando a buscar a partir del "peer0"

#### Cryptopeer.delete_all("prueba.txt")
Permite borrar todas las apariciones del fichero especificado.




