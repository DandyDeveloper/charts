### Charts for numerous project. Migrated from `helm/stable` due to deprecation.

CI to be implemented... 

For now, from each chart: 

```bash
helm package . <package_dir>
mv <package>-*.tgz packagaes
helm repo index packages --url https://dandydeveloper.github.io/charts
git add .
git commit *
git push origin master
```
