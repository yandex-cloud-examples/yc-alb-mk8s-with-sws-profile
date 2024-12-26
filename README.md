# Создание L7-балансировщика с профилем безопасности Yandex Smart Web Security через Ingress-контроллер Yandex Application Load Balancer

Приложения в кластере [Yandex Managed Service for Kubernetes®](https://yandex.cloud/ru/docs/managed-kubernetes/) можно защитить от DDoS-атак и ботов с помощью сервиса [Smart Web Security](https://yandex.cloud/ru/smartwebsecurity/concepts/index.md). Для этого опубликуйте приложения через ресурс Ingress, которому назначен [профиль безопасности](https://yandex.cloud/ru/smartwebsecurity/concepts/profiles.md) и который использует Ingress-контроллер Application Load Balancer.

Подготовка инфраструктуры для Managed Service for Kubernetes® и Application Load Balancer через Terraform описана в [практическом руководстве](https://yandex.cloud/ru/smartwebsecurity/tutorials/alb-ingress-with-sws-profile). Необходимый для настройки конфигурационный файл [alb-ready-k8s-cluster.tf](alb-ready-k8s-cluster.tf) расположен в этом репозитории.
