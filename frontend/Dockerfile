FROM node:20.11.0 AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ENV REACT_APP_BACKEND_URL=/api
RUN npm run build

FROM nginx:1.29.2
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]