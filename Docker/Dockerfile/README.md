# 1. Instructions

ADD - Quando copiando um tar.gz, ele descompacta automaticamente se a copia for local, se for da internet nao descompacta
COPY
WORKDIR  Workdir tb é o local onde vai ser o diretório inicial ao executar o container 

ENTRYPOINT é o principal processos
CMD são os parâmetros do entrypoint, quando se tem ele
Da pra usar só o CMD sozinho, mas o correto é com entrypoint 


# 2. Layers
- Layers are read-only
- 

docker image ls mostra o tamanho geral
docker history --human app:1.0 << entender aqui pra ver se vale a pena mostrar
    mostra a camada de 200MB sendo removida
O comando docker history mostra o histórico de construção de uma imagem Docker, incluindo as instruções utilizadas e o tamanho que cada uma adicionou à imagem.

No seu caso, ele é especialmente útil para demonstrar que as camadas de uma imagem são Read-Only (RO).
#### tem mais detalhes no chatGPT


Daqui pra baixo, vou diminuindo o tamanho da img

mudar pra go-lang menor, atualmente usa 1.3GB

