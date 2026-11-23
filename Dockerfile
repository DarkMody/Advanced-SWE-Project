# ---- build stage ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY src/PayLink.Api/PayLink.Api.csproj src/PayLink.Api/
RUN dotnet restore src/PayLink.Api/PayLink.Api.csproj
COPY src/ src/
RUN dotnet publish src/PayLink.Api/PayLink.Api.csproj -c Release -o /app/publish --no-restore

# ---- runtime stage ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "PayLink.Api.dll"]
