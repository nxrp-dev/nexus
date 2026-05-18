<#list SchemaForge as lRow>
insert into ${TABLE_NAME}_TBL (
  <#list SchemaForge.headers as lHeader>
	${lHeader}<#if lHeader_has_next>,</#if>
  </#list>
) values (
  <#list SchemaForge.headers as lHeader>
	'${lRow[lHeader]}'<#if lHeader_has_next>,</#if> 	--- ${lHeader}
  </#list>
);
</#list>
commit;