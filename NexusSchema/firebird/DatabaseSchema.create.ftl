[#ftl]
[#-- Global Constants --]
[#assign cModulePostfix = SchemaForge.MetaData.@MODULE_POSTFIX]
[#assign cModuleIDPostfix = SchemaForge.MetaData.@MODULE_ID_POSTFIX]
[#assign cGeneratorPrefix = SchemaForge.MetaData.@GENERATOR_PREFIX]

[#-- Function Declarations. --]
[#macro CreateTableSupport ATableName]
  create generator ${cGeneratorPrefix}${ATableName}${cModuleIDPostfix};
  commit;

  alter table ${ATableName}${cModulePostfix} add primary key (${ATableName}${cModuleIDPostfix});
  commit;

  set term ^ ;
  create trigger BI_${ATableName}_GT for ${ATableName}${cModulePostfix}
  active before insert position 0 as
  begin
    if (new.${ATableName}${cModuleIDPostfix} is null) then
      new.${ATableName}${cModuleIDPostfix} = GEN_ID(${cGeneratorPrefix}${ATableName}${cModuleIDPostfix}, 1);
  end^
  set term ; ^
  commit;
[/#macro]

[#macro CreateHistoryTrigger ATable]
  set term ^ ;
  create trigger AI_${ATable.Name}_HT FOR ${ATable.Name}${cModulePostfix}
  active after insert or update position 0
  as
  begin
    insert into ${ATable.Name}_H${cModulePostfix} (
[#--      ${ATable.Name}_H${cModuleIDPostfix}, --]
      [#list ATable.Fields.Field as lField]
      ${lField.Name}[#if lField_has_next],[/#if]
      [/#list]
    ) values (
[#--      GEN_ID(${cGeneratorPrefix}${ATable.Name}_H${cModuleIDPostfix}, 1), --]
      [#list ATable.Fields.Field as lField]
      New.${lField.Name} [#if lField_has_next],[/#if]
      [/#list]
    );
  end^
  set term ; ^
  commit;
[/#macro]

[#macro CreateHistoryTable ATable]
  [#assign lHistoryName="${ATable.Name}_H"/]
  create table ${lHistoryName}${cModulePostfix} (
    ${lHistoryName}${cModuleIDPostfix} DOM_INDEX NOT NULL,
    ${ATable.Name}${cModuleIDPostfix} DOM_INDEX NOT NULL,
    [#list ATable.Fields.Field as lField]
    ${lField.Name} ${lField.FieldType}[#if lField_has_next],[/#if]
    [/#list]
  );
  commit;

  [@CreateTableSupport lHistoryName/]   

  [@CreateHistoryTrigger ATable/]
  
  CREATE INDEX IDX_${lHistoryName}_${ATable.Name} ON ${lHistoryName}${cModulePostfix}(${ATable.Name}${cModuleIDPostfix});
  commit;
[/#macro]

[#macro CreateTable ATable]
  create table ${ATable.Name}${cModulePostfix} (
    ${ATable.Name}${cModuleIDPostfix} DOM_INDEX NOT NULL,
    [#list ATable.Fields.Field as lField]
    ${lField.Name} ${lField.FieldType}[#if lField_has_next],[/#if]
    [/#list]
  );
  commit;

[@CreateTableSupport ATable.Name/] 
[/#macro]

[#macro InsertReportTable ATable]
  INSERT INTO REPORT_TABLE_TBL(TABLE_NAME, ALIAS) 
    VALUES('${ATable.Name}${cModulePostfix}', '${ATable.Name}');   
[/#macro]

[#macro InsertReportFields ATable]
    [#list ATable.Fields.Field as lField]
      INSERT INTO REPORT_FIELD_TBL
             (REPORT_TABLE_ID, TABLE_NAME, FIELD_NAME, DATA_TYPE, SELECTABLE, SEARCHABLE, SORTABLE, AUTOSEARCH, MANDATORY, FIELD_ALIAS)
      VALUES((SELECT REPORT_TABLE_ID FROM REPORT_TABLE_TBL WHERE TABLE_NAME = '${ATable.Name}${cModulePostfix}'), '${ATable.Name}${cModulePostfix}', '${lField.Name}', '${lField.FieldType}', 'T', 'T', 'T', 'F', 'F', 'F');
      
      commit;
  --
  --
    [/#list]
[/#macro]

[#macro InsertReportJoins ATable]
  [#list ATable.ForeignKeys.ForeignKey as lForeignKey]
  [#-- [#assign lFKName = "FK_${lTable.Name}_${lForeignKey.Field}"] --] 

    INSERT INTO REPORT_JOIN_TBL
           (TABLE_MASTER, TABLE_DETAIL, JOIN_TYPE, FIELD_MASTER, FIELD_DETAIL, OPERATORS)
    VALUES('${ATable.Name}${cModulePostfix}', '${lForeignKey.ReferenceEntity}${cModulePostfix}', 'INNER', '${lForeignKey.Field}', '${lForeignKey.ReferenceEntity}${cModuleIDPostfix}', '=');

    commit;
  --
  --
  [/#list]
  ------------------------------------------------------------------------------------------------------------------------------
[/#macro]

[#-- Main Body --]

---------------------------------------------------------------------------------------------------------
--[ Domains ----------------------------------------------------------------------------------------------]--
[#list SchemaForge.MetaData.Module as lModule]
--[ ${lModule.Name} ----------------------------------------------------------------------------------------------]--
  [#list lModule.Domains.Item as lItem]
create domain ${lItem.Name} as ${lItem.Value};
  [/#list]
[/#list]
commit;

[#list SchemaForge.MetaData.Module as lModule]
--[ ${lModule.Name} ----------------------------------------------------------------------------------------------]--
  [#list lModule.Tables.Table as lTable]
  -- ${lTable.Name} -------------------------------------------------------------------------------------------------------------
  [@CreateTable lTable/]

  [#-- History Schema --]
  [#assign lIsHistory = lTable.@IS_HISTORY[0]!"False"]
  [#if lIsHistory = "True"]
    [@CreateHistoryTable lTable/]
  [/#if]
  ------------------------------------------------------------------------------------------------------------------------------
  [/#list]
--[----------------------------------------------------------------------------------------------------------------------------]--  
[/#list]

[#list SchemaForge.MetaData.Module as lModule]
--[ ${lModule.Name}  --------------------------------------------------------------------------------------]--
  [#list lModule.Tables.Table as lTable]
  -- ${lTable.Name} -------------------------------------------------------------------------------------------------------------
    [#assign lFKIndex = 0]
    [#list lTable.ForeignKeys.ForeignKey as lForeignKey]
      [#assign lFKIndex = lFKIndex + 1]
      [#assign lFKName = "FK_${lTable.Name}_${lForeignKey.Field}"]   
      alter table ${lTable.Name}${cModulePostfix} add constraint ${lFKName?right_pad(30)?substring(0, 30)?trim + lFKIndex} foreign key (${lForeignKey.Field}) references ${lForeignKey.ReferenceEntity}${cModulePostfix} (${lForeignKey.ReferenceEntity}${cModuleIDPostfix}); 
	[/#list]
  ------------------------------------------------------------------------------------------------------------------------------
  [/#list]
--[----------------------------------------------------------------------------------------------------------------------------]--  
[/#list]
commit;


[#-- Populate Report Tables --]

[#list SchemaForge.MetaData.Module as lModule]
--[ ${lModule.Name} ----------------------------------------------------------------------------------------------]--
  [#list lModule.Tables.Table as lTable]
  -- ${lTable.Name} -------------------------------------------------------------------------------------------------------------
    [@InsertReportTable lTable/]
    [@InsertReportFields lTable/]
    [@InsertReportJoins lTable/]
  ------------------------------------------------------------------------------------------------------------------------------
  [/#list]
--[----------------------------------------------------------------------------------------------------------------------------]--  
[/#list]
