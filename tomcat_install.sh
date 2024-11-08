#!/bin/bash

# 로그 파일 설정
LOG_FILE="/tmp/tomcat_install.log"
exec 2> >(tee -a "$LOG_FILE")  # 오류 메시지를 로그 파일에 기록

# 설치할 톰캣 버전 선택
echo "설치할 Tomcat 버전을 선택하세요:"
echo "1) Tomcat 8.0"
echo "2) Tomcat 8.5"
echo "3) Tomcat 9.0"
echo "4) Tomcat 10.0"
echo "5) Tomcat 10.1"
echo "6) Tomcat 11.0"
read -p "번호를 입력하세요 (1, 2, 3, 4, 5, 6): " version_choice

case $version_choice in
  1)
    TOMCAT_MAJOR="8"
    TOMCAT_VERSION="8.0"
    ;;
  2)
    TOMCAT_MAJOR="8"
    TOMCAT_VERSION="8.5"
    ;;
  3)
    TOMCAT_MAJOR="9"
    TOMCAT_VERSION="9.0"
    ;;
  4)
    TOMCAT_MAJOR="10"
    TOMCAT_VERSION="10.0"
    ;;
  5)
    TOMCAT_MAJOR="10"
    TOMCAT_VERSION="10.1"
    ;;
  6)
    TOMCAT_MAJOR="11"
    TOMCAT_VERSION="11.0"
    ;;
  *)
    echo "잘못된 입력입니다. 스크립트를 종료합니다."
    exit 1
    ;;
esac

# Java 설치 경로
JAVA_DIR="/usr/local/java"

# Java 설치 함수
install_java() {
  local JAVA_URL=$1
  sudo mkdir -p "$JAVA_DIR"
  if [[ $? -ne 0 ]]; then
    echo "디렉토리 생성에 실패했습니다: $JAVA_DIR" | tee -a "$LOG_FILE"
    return 1
  fi
  
  cd /tmp || exit
  wget "$JAVA_URL" -O java.tar.gz 2>> "$LOG_FILE"
  if [[ $? -ne 0 || ! -f "java.tar.gz" ]]; then
    echo "Java 다운로드에 실패했습니다. 설치를 중단합니다." | tee -a "$LOG_FILE"
    rm -f java.tar.gz
    return 1
  fi

  sudo tar -zxvf java.tar.gz -C "$JAVA_DIR" --strip-components=1 >> "$LOG_FILE" 2>&1
  if [[ $? -ne 0 || ! -d "$JAVA_DIR" || -z "$(ls -A $JAVA_DIR)" ]]; then
    echo "Java 설치에 실패했습니다. 설치를 중단합니다." | tee -a "$LOG_FILE"
    rm -f java.tar.gz
    sudo rm -rf "$JAVA_DIR"
    return 1
  fi

  rm java.tar.gz
  return 0
}

# Java 설치 및 환경 변수 설정 함수
setup_java() {
  local JAVA_URL=$1
  install_java "$JAVA_URL"
  if [[ $? -ne 0 ]]; then
    echo "Java 설치에 실패하여 환경 변수를 등록하지 않았습니다. Java를 수동으로 설치해야 합니다." | tee -a "$LOG_FILE"
    return 1
  fi

  # 자바 환경 변수 설정
  echo "export JAVA_HOME=$JAVA_DIR" | sudo tee -a /etc/profile
  echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/profile
  source /etc/profile

  # 설치 후 3초 대기
  sleep 3
  return 0
}

# Tomcat 11 설치 시 자바 17 버전 이상 필요 확인
if [[ "$TOMCAT_VERSION" == "11.0" ]]; then
  if type -p java > /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    JAVA_MAJOR_VERSION=$(echo $JAVA_VERSION | cut -d'.' -f1)
    
    if [[ "$JAVA_MAJOR_VERSION" -lt 17 ]]; then
      echo "현재 Java 버전은 $JAVA_VERSION입니다. Tomcat ${TOMCAT_VERSION}을 설치하려면 Java 17 이상이 필요합니다."
      read -p "Java 17을 압축 파일로 설치하시겠습니까? (y/n): " install_java_choice
      if [[ "$install_java_choice" == "y" ]]; then
        # Java 17 다운로드 및 설치 (고정된 URL 사용)
        JAVA_URL="https://download.oracle.com/java/17/archive/jdk-17.0.12_linux-x64_bin.tar.gz"
        setup_java "$JAVA_URL"
      else
        echo "Java 17이 설치되지 않아 수동으로 설치해야 합니다." | tee -a "$LOG_FILE"
      fi
    fi
  else
    echo "Java가 설치되어 있지 않습니다. Tomcat ${TOMCAT_VERSION}을 설치하려면 Java 17 이상이 필요합니다."
    read -p "Java 17을 압축 파일로 설치하시겠습니까? (y/n): " install_java_choice
    if [[ "$install_java_choice" == "y" ]]; then
      # Java 17 다운로드 및 설치 (고정된 URL 사용)
      JAVA_URL="https://download.oracle.com/java/17/archive/jdk-17.0.12_linux-x64_bin.tar.gz"
      setup_java "$JAVA_URL"
    else
      echo "Java 17이 설치되지 않아 수동으로 설치해야 합니다." | tee -a "$LOG_FILE"
    fi
  fi
fi

# Tomcat 10 이하 버전 설치 시 자바 1.8 설치 확인
if [[ "$TOMCAT_MAJOR" -le 10 ]]; then
  if ! type -p java > /dev/null; then
    echo "Java가 설치되어 있지 않습니다. Tomcat ${TOMCAT_VERSION}을 설치하려면 Java 1.8이 필요합니다."
    read -p "Java 1.8을 압축 파일로 설치하시겠습니까? (y/n): " install_java_choice
    if [[ "$install_java_choice" == "y" ]]; then
      # Java 1.8 다운로드 및 설치
      JAVA_URL="https://download.oracle.com/otn-pub/java/jdk/8u301-b09/jdk-8u301-linux-x64.tar.gz"
      setup_java "$JAVA_URL"
    else
      echo "Java 1.8이 설치되지 않아 수동으로 설치해야 합니다." | tee -a "$LOG_FILE"
    fi
  fi
fi

# Tomcat 다운로드 URL 설정 (메이저 버전 먼저 확인 후 마이너 버전 찾기)
BASE_URL="https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR}/"
LATEST_MINOR_VERSION=""

# 최신 패치 버전 확인 및 다운로드 URL 설정
for version in $(curl -s "${BASE_URL}" | grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/v//g' | sort -V -r); do
  if [[ $version == ${TOMCAT_VERSION}* ]]; then
    LATEST_MINOR_VERSION=$version
    break
  fi
done

if [ -z "$LATEST_MINOR_VERSION" ]; then
  echo "해당 Tomcat 버전의 다운로드 URL을 찾을 수 없습니다." | tee -a "$LOG_FILE"
  exit 1
fi

DOWNLOAD_URL="${BASE_URL}v${LATEST_MINOR_VERSION}/bin/apache-tomcat-${LATEST_MINOR_VERSION}.tar.gz"

# 다운로드 및 설치
INSTALL_DIR="/usr/local/tomcat${TOMCAT_VERSION}"
sudo mkdir -p "$INSTALL_DIR" 2>> "$LOG_FILE"
cd /tmp || exit
wget "$DOWNLOAD_URL" -O tomcat.tar.gz 2>> "$LOG_FILE"
sudo tar -zxvf tomcat.tar.gz -C "$INSTALL_DIR" --strip-components=1 >> "$LOG_FILE" 2>&1
rm tomcat.tar.gz

# 권한 설정
sudo chown -R $(whoami):$(whoami) "$INSTALL_DIR" 2>> "$LOG_FILE"
sudo chmod +x "$INSTALL_DIR"/bin/*.sh 2>> "$LOG_FILE"

# 환경 변수 설정
echo "export CATALINA_HOME=$INSTALL_DIR" >> ~/.bashrc
echo "export PATH=\$PATH:\$CATALINA_HOME/bin" >> ~/.bashrc
source ~/.bashrc

echo "Tomcat ${LATEST_MINOR_VERSION}가 ${INSTALL_DIR}에 설치되었습니다."
echo "설치 로그는 ${LOG_FILE}에 저장되었습니다."
