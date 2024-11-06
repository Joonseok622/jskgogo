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

# Tomcat 10.1 이상 버전 설치 시 자바 버전 확인
if [[ "$TOMCAT_MAJOR" -ge 10 ]] && [[ "$TOMCAT_VERSION" != "10.0" ]]; then
  if type -p java > /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    JAVA_MAJOR_VERSION=$(echo $JAVA_VERSION | cut -d'.' -f1)
    
    if [[ "$JAVA_MAJOR_VERSION" -lt 11 ]]; then
      echo "현재 Java 버전은 $JAVA_VERSION입니다. Tomcat ${TOMCAT_VERSION}을 설치하려면 Java 11 이상이 필요합니다."
      read -p "Java 11을 설치하시겠습니까? (y/n): " install_java
      if [[ "$install_java" == "y" ]]; then
        if command -v yum &> /dev/null; then
          sudo yum install -y java-11-openjdk-devel 2>> "$LOG_FILE"
        elif command -v apt-get &> /dev/null; then
          sudo apt-get update >> "$LOG_FILE" 2>&1
          sudo apt-get install -y openjdk-11-jdk >> "$LOG_FILE" 2>&1
        else
          echo "지원하지 않는 패키지 매니저입니다. 수동으로 Java 11을 설치하세요." | tee -a "$LOG_FILE"
          exit 1
        fi
        # 설치 후 3초 대기
        sleep 3
      else
        echo "Java 11이 설치되지 않아 Tomcat 설치를 취소합니다." | tee -a "$LOG_FILE"
        exit 1
      fi
    fi
  else
    echo "Java가 설치되어 있지 않습니다. Tomcat ${TOMCAT_VERSION}을 설치하려면 Java 11 이상이 필요합니다."
    read -p "Java 11을 설치하시겠습니까? (y/n): " install_java
    if [[ "$install_java" == "y" ]]; then
      if command -v yum &> /dev/null; then
        sudo yum install -y java-11-openjdk-devel 2>> "$LOG_FILE"
      elif command -v apt-get &> /dev/null; then
        sudo apt-get update >> "$LOG_FILE" 2>&1
        sudo apt-get install -y openjdk-11-jdk >> "$LOG_FILE" 2>&1
      else
        echo "지원하지 않는 패키지 매니저입니다. 수동으로 Java 11을 설치하세요." | tee -a "$LOG_FILE"
        exit 1
      fi
      # 설치 후 3초 대기
      sleep 3
    else
      echo "Java 11이 설치되지 않아 Tomcat 설치를 취소합니다." | tee -a "$LOG_FILE"
      exit 1
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
