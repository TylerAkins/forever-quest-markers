local instanceGroups = {}
local legacyGroups = {
    {
        allianceQuestData = q(200, {
            qg = 2,
            coord = { 20, 30, MAP.ELWYNN_FOREST },
        }),
        hordeQuestData = q(201, {
            qg = 3,
            coord = { 30, 40, MAP.ORGRIMMAR },
        }),
    },
}
for i,o in ipairs(legacyGroups) do
    table.insert(instanceGroups, o)
end

root(ROOTS.Instances, {
    inst(1000, {
        sourceQuest = 100,
        groups = {
            q(100, {
                sourceQuest = 90,
                altQuests = { 101 },
                qg = 1,
                coord = { 10, 20, MAP.ELWYNN_FOREST },
            }),
            q(101, {
                altQuests = { 100 },
                qg = 1,
                coord = { 10, 20, MAP.ELWYNN_FOREST },
            }),
            q(90, {
                sourceQuests = { 80, 81 },
                qg = 1,
                coord = { 11, 21, MAP.ELWYNN_FOREST },
            }),
            q(80, {
                qg = 1,
                coord = { 12, 22, MAP.ELWYNN_FOREST },
            }),
            q(81, {
                qg = 1,
                coord = { 13, 23, MAP.ELWYNN_FOREST },
            }),
        },
    }),
    inst(1001, {
        sourceQuests = { 200, 201 },
        groups = instanceGroups,
    }),
})
