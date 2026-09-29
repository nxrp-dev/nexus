# Package target resolution

The earlier pause used a consumer with only TargetOS selected, while its imported
compiler package had alternative TargetCPU outputs with the same name. Without a
CPU selection both alternatives survived and compilation rejected the duplicate.

The owner clarified that the real compiler/application examples require both CPU
and OS. That incomplete example does not justify changing language rules. Fixtures
now supply complete selections. Forge compiles each dependency request and its
imported configuration definitions with that dependency's own Targets.

NexusScript module loading, target filtering, and duplicate-name rules remain
unchanged. Any future valid example requiring different behavior must be reviewed
with the owner before changing those rules.
