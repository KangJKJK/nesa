#!/bin/bash

YELLOW='\033[1;33m'
NC='\033[0m'

# 메인 설치 함수
install_node() {
    # 필요한 패키지 설치
    sudo apt update && sudo apt install curl && apt install jq -y

    # 도커 설치
    if ! command -v docker &> /dev/null; then
        echo "Docker 설치 중..."
        
        for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
            sudo apt-get remove -y $pkg
        done

        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        
        sudo apt update -y && sudo apt install -y docker-ce
        sudo systemctl start docker
        sudo systemctl enable docker

        echo "Docker Compose 설치 중..."

        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        echo "Docker가 성공적으로 설치되었습니다."
    else
        echo "Docker가 이미 설치되어 있습니다."
    fi

    # Node.js 설치
    echo -e "${YELLOW}Node.js LTS 버전을 설치하고 설정 중...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
    sudo apt install -y nodejs

    echo -e "${YELLOW}해당사이트에서 API 키를 받아주세요.${NC}"
    echo -e "${YELLOW}프로필아이콘-설정-엑세스토큰-새토큰만들기를 클릭하시면 됩니다.${NC}"
    echo -e "${YELLOW}https://huggingface.co/join${NC}"
    echo -e "${YELLOW}Leap wallet을 다운받아서 개인키를 복사해주세요.${NC}"
    read -p "위 단계들을 완료하셨으면 엔터를 눌러주세요."

    echo -e "${YELLOW}설치명령어가 실행되면 다음 설정들을 입력해주세요.${NC}"
    echo -e "${YELLOW}Wizardy-노드이름-이메일-추천코드-API키-개인키${NC}"
    echo -e "${YELLOW}레퍼럴 코드는 대시보드 사이트에서 접속한 후 월렛을 연결하고 지갑을 열어서 nesa로 시작하는 주소를 입력하세요.${NC}"
    echo -e "${YELLOW}셀퍼럴을 진행하시거나 nesa16aez63l50mnc8w0k6pvyhku2xcskzvcf39l8wg 를 입력해주세요.${NC}"
    echo -e "${YELLOW}실행 후 포트충돌이 예상되므로 스크립트를 재실행하여 포트를 변경해주세요.${NC}"
    echo -e "${YELLOW}대시보드 사이트는 다음과 같습니다: https://node.nesa.ai/${NC}"
    read -p "위 단계들을 확인하셨으면 엔터를 눌러주세요."

    # 설치프로그램 실행
    bash <(curl -s https://raw.githubusercontent.com/nesaorg/bootstrap/master/bootstrap.sh)
}

# 포트 변경 및 재시작 함수
change_port_and_restart() {
    echo -e "${YELLOW}현재 실행 중인 Nesa 관련 컨테이너 목록:${NC}"
    docker ps --filter "name=nesa" --format "ID: {{.ID}}, Name: {{.Names}}, Ports: {{.Ports}}"

    # 컨테이너 ID 입력
    read -p "위에 노출된 nesa 컨테이너 ID를 입력하세요: " container_id

    # 컨테이너 중지
    echo -e "${YELLOW}컨테이너를 중지합니다...${NC}"
    docker stop $container_id
    
    # 현재 사용 중인 포트 확인
    used_ports=$(docker ps --format "{{.Ports}}" | grep -oP '(?<=:)\d+(?=->)' | sort -n)
    echo -e "${YELLOW}현재 사용 중인 포트 목록:${NC}"
    echo "$used_ports"
    
    # 사용 가능한 다음 포트 찾기
    last_port=8080
    for port in $used_ports; do
        if [ $port -ge $last_port ]; then
            last_port=$((port + 1))
        fi
    done
    
    echo -e "${YELLOW}사용 가능한 포트는 다음과 같습니다: $last_port${NC}"
    
    # docker-compose.yml 파일 수정
    echo -e "${YELLOW}포트를 $last_port로 변경합니다...${NC}"
    cd /root/.nesa/docker
    sed -i "s/- [0-9]\+:8080/- $last_port:8080/" compose.ipfs.yml
    
    # 노드 재시작
    echo -e "${YELLOW}노드를 재시작합니다...${NC}"
    read -p "대시보드 사이트는 다음과 같습니다: https://node.nesa.ai/ : 엔터"
    bash <(curl -s https://raw.githubusercontent.com/nesaorg/bootstrap/master/bootstrap.sh)
}

# 메인 메뉴
while true; do
    echo -e "\n${YELLOW}=== Nesa 노드 설치 관리자 ===${NC}"
    echo "1) 노드 설치"
    echo "2) 포트 변경 및 재시작"
    echo "3) 종료"
    read -p "선택하세요 (1-3): " choice

    case $choice in
        1)
            install_node
            ;;
        2)
            change_port_and_restart
            ;;
        3)
            echo "프로그램을 종료합니다."
            exit 0
            ;;
        *)
            echo "잘못된 선택입니다. 1-3 중에서 선택해주세요."
            ;;
    esac
done
