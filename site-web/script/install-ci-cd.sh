#!/bin/bash

echo "=========================================="
echo " INSTALLATION DU SYSTÈME CI/CD COMPLET"
echo "=========================================="
echo "Ce script va installer :"
echo " Jenkins"
echo " NGINX"
echo " Git"
echo " Java"
echo " Votre site web"
echo "=========================================="

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    echo " ERREUR: Veuillez exécuter le script en tant que root :"
    echo "sudo ./install-ci-cd.sh"
    exit 1
fi

# Configuration
SITE_DIR="/var/www/html"
JENKINS_URL="http://192.168.12.1"

echo ""
echo " Étape 1: Mise à jour du système..."
apt update
apt upgrade -y

echo ""
echo " Étape 2: Installation des dépendances..."
apt install -y \
    openjdk-11-jdk \
    wget \
    curl \
    git \
    nginx \
    software-properties-common

echo ""
echo " Étape 3: Installation de Jenkins..."
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt update
apt install -y jenkins

echo ""
echo " Étape 4: Configuration de NGINX..."
# Créer la configuration NGINX pour le site web
cat > /etc/nginx/sites-available/ci-cd-site << EOF
server {
    listen 80;
    server_name _;
    root $SITE_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Empêcher l'accès aux fichiers .git
    location ~ /\.git {
        deny all;
    }

    # Configuration des types MIME
    location ~* \.(html|css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1h;
        add_header Cache-Control "public";
    }
}
EOF

# Activer le site et désactiver le site par défaut
ln -sf /etc/nginx/sites-available/ci-cd-site /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo ""
echo " Étape 5: Configuration des répertoires..."
# Créer le répertoire du site web
mkdir -p $SITE_DIR
chown -R www-data:www-data $SITE_DIR
chmod -R 755 $SITE_DIR

echo ""
echo " Étape 6: Démarrage des services..."
systemctl daemon-reload
systemctl enable jenkins nginx
systemctl start jenkins nginx

echo ""
echo " Étape 7: Configuration du firewall..."
# Vérifier si ufw est installé et le configurer
if command -v ufw &> /dev/null; then
    ufw allow 80
    ufw allow 8080
    ufw allow 22
    ufw --force enable
fi

echo ""
echo " Étape 8: Attente du démarrage de Jenkins..."
echo "Patientez 30 secondes que Jenkins soit complètement démarré..."
sleep 30

# Vérifier que Jenkins est en cours d'exécution
if ! systemctl is-active --quiet jenkins; then
    echo " Jenkins n'est pas démarré, redémarrage..."
    systemctl start jenkins
    sleep 10
fi

echo ""
echo " Étape 9: Récupération des informations importantes..."
JENKINS_PASSWORD=""
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
else
    echo "  Le fichier de mot de passe Jenkins n'est pas encore disponible"
    echo " Exécutez cette commande plus tard :"
    echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi

# Obtenir l'adresse IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS="127.0.0.1"
fi

echo ""
echo "=========================================="
echo " INSTALLATION TERMINÉE AVEC SUCCÈS"
echo "=========================================="
echo ""
echo " ACCÈS AUX SERVICES :"
echo "------------------------------------------"
echo " Jenkins:  http://$IP_ADDRESS:8080"
if [ -n "$JENKINS_PASSWORD" ]; then
    echo " Mot de passe Jenkins: $JENKINS_PASSWORD"
else
    echo " Mot de passe Jenkins: Exécutez: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi
echo ""
echo " Site web: http://$IP_ADDRESS"
echo " Dossier du site: $SITE_DIR"
echo ""
echo " PROCHAINES ÉTAPES :"
echo "------------------------------------------"
echo "1. Accédez à Jenkins: http://$IP_ADDRESS:8080"
echo "2. Utilisez le mot de passe ci-dessus"
echo "3. Installez les plugins suggérés"
echo "4. Créez un utilisateur administrateur"
echo "5. Configurez votre pipeline Jenkins"
echo ""
echo " POUR DÉPLOYER VOTRE SITE :"
echo "------------------------------------------"
echo "sudo cp -r ~/projet-ci-cd/site-web/* $SITE_DIR/"
echo "sudo chown -R www-data:www-data $SITE_DIR"
echo "=========================================="