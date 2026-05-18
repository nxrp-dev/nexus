[#ftl]
[#-- Global Constants --]
[#assign cModulePostfix = SchemaForge.MetaData.@MODULE_POSTFIX]
[#assign cModuleIDPostfix = SchemaForge.MetaData.@MODULE_ID_POSTFIX]
[#assign cGeneratorPrefix = SchemaForge.MetaData.@GENERATOR_PREFIX]

[#-- Macros --]

[#macro CreateDocumentHeader]
<?xml version="1.0"?>
<Provider_Server_Header ClassName="TProviderServer">
  <Provider_Server>
    <Categories>    
      <Items>
[/#macro]

[#macro CreateDocumentFooter]
      </Items>
    </Categories>
    <Databases>
      <Items>
        <TPluginModule Name="SQL92" PluginClassName="TDatabaseDefinition"/>
        <TPluginModule Name="SQL92" FileName="X:\projects\inForceServer\libFirebirdPlugin.bpl.1" PluginClassName="TFirebirdDefinition"/>
      </Items>
    </Databases>
    </Provider_Server>
</Provider_Server_Header>
[/#macro]

[#macro CreateCategoryHeader ACategory]
        <TProviderCategory Name="${ACategory}">
          <Providers>
            <Items> 
[/#macro]

[#macro CreateCategoryFooter]
            </Items>
          </Providers>
        </TProviderCategory>
[/#macro]

[#macro CreateProviderHeader ATableName]
  <TProviderDefinition Name="${ATableName}Edit" ResolveToDataset="False" CustomResolution="False" UpdateMode="upWhereAll" ProviderOptions="poFetchDetailsOnDemand" KeyFields="${ATableName}${cModuleIDPostfix}">
[/#macro]

[#macro CreateProviderFooter]
  </TProviderDefinition>
[/#macro]

[#macro CreateSQLStatementHeader AKeyField]
  <SQLStatement KeyFields="${AKeyField}">
  <Items>
[/#macro]

[#macro CreateSQLStatementFooter]
  </Items>
  </SQLStatement>
  <Header IsSingtleton="False" IsLookupTable="False"/>
[/#macro]

[#macro CreateEditSQLStatement ATableName AKeyField]
    <TSQLElement Name="SQL92" SelectSQL="select * from ${ATableName} where ${AKeyField} = :${AKeyField}"/>
[/#macro]

[#macro CreateEditProvider AProviderName ATableName AKeyField]
    [@CreateProviderHeader AProviderName/]
    [@CreateSQLStatementHeader AKeyField/]
    [@CreateEditSQLStatement ATableName AKeyField/]
    [@CreateSQLStatementFooter/]
    [@CreateProviderFooter/]
[/#macro]

[#-- Main Body --]

[@CreateDocumentHeader/]
[#list SchemaForge.MetaData.Module as lModule]
  [#assign lCategoryName = "AUTO_${lModule.Name}"]
  [@CreateCategoryHeader lCategoryName/]
  [#list lModule.Tables.Table as lTable]
    [#assign lTableID = "${lTable.Name}${cModuleIDPostfix}"]
    [#assign lTableName = "${lTable.Name}${cModulePostfix}"]
    [#assign lProviderName = "${lTable.Name}"]
    [@CreateEditProvider lProviderName lTableName lTableID/]
  [/#list]
  [@CreateCategoryFooter/]    
[/#list]
[@CreateDocumentFooter/]