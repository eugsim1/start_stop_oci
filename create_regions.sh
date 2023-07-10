source  setAPI.env

mkdir -vp configuration_data
ansible-playbook  01-regions.yaml

### delete last line
sed -r '/^\s*$/d' -i configuration_data/regions_form.csv 
cat                  configuration_data/regions_form.csv     
